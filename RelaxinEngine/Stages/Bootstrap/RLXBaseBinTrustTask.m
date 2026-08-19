//
//  RLXBaseBinTrustTask.m
//  RelaxinEngine
//

#import "RLXBaseBinTrustTask.h"

#import "../../Engine/RLXEngine.h"
#import "../../Diagnostic/RLXEngineDiagnostic.h"
#import "../../Engine/RLXEngineError.h"
#import "../../Log/RLXEngineLog.h"
#import "../../Engine/RLXEngineRunContext.h"
#import "../../KernelAccess/RLXKernelAccess.h"
#import "../../KernelAccess/Analysis/RLXKernelInfo.h"

#include <errno.h>
#include <string.h>

#include <libjailbreak/info.h>
#include <libjailbreak/roothider/common.h>
#include <libjailbreak/trustcache.h>
#include <libjailbreak/trustcache_nokcall.h>

static const char *const RLXBaseBinTrustLogCategory = "BaseBinTrust";

static NSError *rlx_basebin_trust_error(NSString *phase, int status, NSString *detail) {
    NSString *statusDescription = status > 0 ? @(strerror(status)) : @"unknown error";
    NSString *logMessage = [NSString
        stringWithFormat:@"failed phase=%@ status=%d (%@)%@",
                         phase,
                         status,
                         statusDescription,
                         detail.length ? [NSString stringWithFormat:@" detail={%@}", detail] : @""];
    rlx_engine_log(RLX_ENGINE_LOG_ERROR, RLXBaseBinTrustLogCategory, logMessage.UTF8String);
    RLXEngineDiagnostic *diagnostic = [RLXEngineDiagnostic diagnostic];
    [diagnostic appendPhase:phase];
    [diagnostic appendStatus:status];
    [diagnostic appendKey:@"status_description" value:statusDescription];
    [diagnostic appendRenderedDiagnostic:detail ?: @""];
    return [RLXEngineError
             errorWithCode:RLXEngineErrorCodeBaseBinTrustFailed
               description:@"BaseBin could not be published to the trust cache."
             failureReason:[NSString
                               stringWithFormat:@"%@ failed with status %d (%@).", phase, status, statusDescription]
        recoverySuggestion:@"Reboot the device before retrying the jailbreak."
                diagnostic:diagnostic];
}

@implementation RLXBaseBinTrustTask

- (instancetype)initWithContext:(RLXEngineRunContext *)context {
    return [super initWithStage:RLXEngineStageBaseBinTrust context:context];
}

- (nullable NSError *)execute {
    NSString *beginMessage = [NSString
        stringWithFormat:@"begin kernel_access_active=%@ " "bootstrap_identity_active=%@ kernel_el=%llu",
                         self.context.kernelAccess.isActive ? @"true" : @"false",
                         self.context.kernelAccess.isBootstrapIdentityActive ? @"true" : @"false",
                         self.context.kernelInfo.kernelExceptionLevel];
    rlx_engine_log(RLX_ENGINE_LOG_VERBOSE, RLXBaseBinTrustLogCategory, beginMessage.UTF8String);

    if (!self.context.kernelAccess.isActive || !self.context.kernelAccess.isBootstrapIdentityActive) {
        return rlx_basebin_trust_error(@"precondition",
                                       ENXIO,
                                       [NSString
                                           stringWithFormat:@"kernel_access_active=%@\n" "bootstrap_identity_active=%@",
                                                            self.context.kernelAccess.isActive ? @"true" : @"false",
                                                            self.context.kernelAccess.isBootstrapIdentityActive
                                                                ? @"true"
                                                                : @"false"]);
    }
    if (!gSystemInfo.jailbreakInfo.rootPath || !gSystemInfo.jailbreakInfo.rootPath[0]
        || !gSystemInfo.jailbreakInfo.jbrand) {
        return rlx_basebin_trust_error(@"precondition",
                                       EINVAL,
                                       [NSString stringWithFormat:@"root_path=%s\njbrand=0x%llx",
                                                                  gSystemInfo.jailbreakInfo.rootPath ?: "(null)",
                                                                  gSystemInfo.jailbreakInfo.jbrand]);
    }

    NSString *rootPath = @(gSystemInfo.jailbreakInfo.rootPath);
    NSString *baseBinPath = [rootPath stringByAppendingPathComponent:@"basebin"];
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:baseBinPath isDirectory:&isDirectory] || !isDirectory) {
        return rlx_basebin_trust_error(@"locate_basebin",
                                       ENOENT,
                                       [NSString stringWithFormat:@"basebin=%@", baseBinPath]);
    }
    NSString *locatedMessage = [NSString stringWithFormat:@"located BaseBin path=%@", baseBinPath];
    rlx_engine_log(RLX_ENGINE_LOG_VERBOSE, RLXBaseBinTrustLogCategory, locatedMessage.UTF8String);

    rlx_engine_log(RLX_ENGINE_LOG_INFO,
                   RLXBaseBinTrustLogCategory,
                   "randomizing BaseBin CDHashes and bootstrapping trust");
    int randomizeStatus = randomizeAndBootstrapBasebinTrustcache(baseBinPath.fileSystemRepresentation);
    if (randomizeStatus != 0) {
        return rlx_basebin_trust_error(@"randomize_and_bootstrap",
                                       randomizeStatus,
                                       [NSString stringWithFormat:@"basebin=%@\nhelper_status=%d\n" "kernel_el=%llu",
                                                                  baseBinPath,
                                                                  randomizeStatus,
                                                                  self.context.kernelInfo.kernelExceptionLevel]);
    }
    rlx_engine_log(RLX_ENGINE_LOG_INFO,
                   RLXBaseBinTrustLogCategory,
                   "BaseBin CDHashes randomized and trust cache published");

    NSArray<NSString *> *verificationArtifacts = @[
        @"jbctl",
        @"opainject",
        @"launchdhook.dylib",
    ];
    for (NSString *artifact in verificationArtifacts) {
        NSString *artifactPath = [baseBinPath stringByAppendingPathComponent:artifact];
        NSString *verificationMessage = [NSString
            stringWithFormat:@"verifying trust cache readback artifact=%@ path=%@", artifact, artifactPath];
        rlx_engine_log(RLX_ENGINE_LOG_VERBOSE, RLXBaseBinTrustLogCategory, verificationMessage.UTF8String);

        cdhash_t cdhash = {0};
        if (ensure_randomized_cdhash(artifactPath.fileSystemRepresentation, cdhash) != 0) {
            return rlx_basebin_trust_error(@"verify_cdhash",
                                           ENOEXEC,
                                           [NSString stringWithFormat:@"artifact=%@\npath=%@", artifact, artifactPath]);
        }

        if (!trustcache_nokcall_is_required()) {
            bool found = false;
            int queryStatus = trustcache_query_cdhash(cdhash, &found);
            if (queryStatus != 0 || !found) {
                return rlx_basebin_trust_error(@"verify_trustcache_readback",
                                               queryStatus ?: ENOENT,
                                               [NSString stringWithFormat:@"artifact=%@\npath=%@\ncdhash_found=%@",
                                                                          artifact,
                                                                          artifactPath,
                                                                          found ? @"true" : @"false"]);
            }
        }
    }

    rlx_engine_log(RLX_ENGINE_LOG_INFO,
                   RLXBaseBinTrustLogCategory,
                   "BaseBin trust cache readback verified for jbctl, " "opainject, and launchdhook");
    return nil;
}

@end

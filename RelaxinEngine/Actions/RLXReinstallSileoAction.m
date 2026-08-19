//
//  RLXReinstallSileoAction.m
//  RelaxinEngine
//

#import "RLXActions.h"

#import "RLXActionRunner.h"
#import "../../RelaxinPostJailbreak/Actions/RLXPostJailbreakActionRunner.h"
#import "../Bootstrap/RLXBootstrapFinalizer.h"

#include <TargetConditionals.h>
#include <errno.h>

#if !TARGET_OS_SIMULATOR

NSError *_Nullable RLXReinstallSileo(NSBundle *resourceBundle, NSString *_Nullable __strong *_Nullable failurePhase) {
    __block NSError *installationError = nil;
    int status = RLXPostJailbreakRunAsEffectiveRoot(
        ^int {
            return RLXPostJailbreakRunUnsandboxed(
                ^int {
                    installationError = [RLXBootstrapFinalizer installBundledPackageNamed:@"sileo"
                                                                           resourceBundle:resourceBundle];
                    if (installationError) {
                        RLXPostJailbreakSetFailurePhase(failurePhase, @"install_sileo");
                        return EIO;
                    }
                    return 0;
                },
                failurePhase);
        },
        failurePhase);
    if (status == 0) {
        return nil;
    }
    return RLXActionExecutionError(RLXEngineActionReinstallSileo,
                                   failurePhase && *failurePhase ? *failurePhase : @"install_sileo",
                                   status,
                                   installationError);
}

#endif /* !TARGET_OS_SIMULATOR */

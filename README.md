# Relaxin

Relaxin is a jailbreak for iOS and iPadOS 16.5.1–17.3.1 on devices with RootHide architecture.

This repository is an open-source snapshot for public audit. It does not accept issues, pull requests, or other external contributions, and it will not receive further open-source updates.

Build and package locally with the Makefile.

## Development

The repository uses the top-level `Makefile` for all build and packaging workflows.

```bash
make build               # Build the iOS app (unsigned)
make ipa                 # Build and package an unsigned IPA
make tipa                # Build and package a no-sandbox TIPA
make bootstrap-resources # Download, ad-hoc sign, and stage the RootHide bootstrap
make check               # Validate the zstd integration contract
make test-host           # Run the host-side trust-cache model and fault-injection tests
make format              # Run Swift and C-family formatters (write)
make format-lint         # Run Swift and C-family formatters in check mode
make scan-license        # Refresh Relaxin/Resources/Licenses.txt from Vendor
make clean               # Remove derived data and generated BaseBin resources
```

## License

Relaxin is licensed under the MIT License. See `LICENSE` for details.

## Credits

Relaxin is an OwnGoal Studio project built by the following members. Relaxin could not have been made alive without any of them.

- [@Lakr233](https://x.com/Lakr233)
- [@0x88FFA357](https://x.com/0x88FFA357)
- [@82Flex](https://x.com/82Flex)
- [@roothideDev](https://x.com/roothideDev)
- [@pattern_F_](https://x.com/pattern_F_)

Relaxin also uses external software and binaries during the jailbreak; refer to the Software License section inside the app.

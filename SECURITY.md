# Security

This project is experimental. Only the latest source revision receives fixes; no formal security support window is promised.

Do not disclose vulnerabilities with sensitive details in public issues. Once this repository is hosted on GitHub, use **Security → Report a vulnerability** if private vulnerability reporting is enabled. If that option is unavailable, open an issue containing only a request for a private reporting channel; wait before sharing an exploit or private data.

Before publishing, the repository owner should enable private vulnerability reporting and review Actions permissions.

The application loads a user-selected native SDK library into its process. Use an SDK you trust. No SDK is downloaded by the build or app. The public build has no updater or telemetry implemented by this project; separately obtained vendor binaries have their own behavior and terms.

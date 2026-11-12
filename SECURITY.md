# Security

The plugin runs `omp` and reads its JSON output. It reads no credentials and makes one network request of its own: once a day, an unauthenticated `GET https://api.github.com/repos/tremklekmz/tern-omp-usage/releases/latest` to see whether a newer version exists. Hide the `updates` part or set `OMP_USAGE_NO_UPDATE_CHECK=1` to turn it off.

It writes only to its data folder (`tern.kv`): your settings, each day's tokens and cost, the last release seen, and a copy of your `extras.luau` made before an update. Clicking the update runs `tern plugin install https://github.com/tremklekmz/tern-omp-usage --force`, which replaces the plugin with the latest code from this repository.

If you find something that could leak account data (emails, account ids, tokens) or run code it shouldn't, please don't open a public issue. Report it privately from the repository's **Security** tab, using **Report a vulnerability**.

Only the latest release is supported.

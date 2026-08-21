# Contributing to omaStream

Thank you for your interest in improving omaStream! 

## Local Development Setup

To develop locally, you should clone the plugin directly into your Omarchy configuration directory using the Omarchy CLI:

```bash
# This creates a local clone in ~/.config/omarchy/plugins/user.omastream/
omarchy plugin clone user.omastream --edit
```

Once cloned, any changes you make will be instantly testable. Just run `omarchy restart shell` to reload the Omarchy environment with your new changes.

## Submitting Changes

1. **Fork** the repository and create your branch from `master`.
2. **Test** your changes locally. Ensure that the core features of the plugin continue to work correctly and that your changes do not introduce any regressions.
3. **Commit** your changes with clear, descriptive commit messages.
4. **Push** to your fork and submit a Pull Request.

Make sure you fill out the Pull Request template entirely so the maintainer has enough context to review your code.

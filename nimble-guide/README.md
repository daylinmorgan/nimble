# Nimble Guide

## Contributing

In order to preview changes to the guide you will need to have `python` installed.
With python you should generate a local `venv` and install `mkdocs-material`:

```sh
python -m venv .venv && ./.venv/bin/pip install 'mkdocs-material>=9.5'
source ./.venv/bin/activate
mkdocs serve
```

To automate `venv` usage and `mkdocs` install you can use the tasks defined in [`config.nims`](./config.nims) and just run:

```sh
nim serve
```


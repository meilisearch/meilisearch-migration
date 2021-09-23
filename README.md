<p align="center">
  <img src="https://github.com/meilisearch/integration-guides/blob/main/assets/logos/logo.svg" alt="MeiliSearch Version Update Script" width="200" height="200" />
</p>

<h1 align="center">MeiliSearch Version Migration Script</h1>

<h4 align="center">
  <a href="https://github.com/meilisearch/MeiliSearch">MeiliSearch</a> |
  <a href="https://docs.meilisearch.com">Documentation</a> |
  <a href="https://slack.meilisearch.com">Slack</a> |
  <a href="https://roadmap.meilisearch.com/tabs/1-under-consideration">Roadmap</a> |
  <a href="https://www.meilisearch.com">Website</a> |
  <a href="https://docs.meilisearch.com/faq">FAQ</a>
</h4>

<p align="center">
  <a href="https://github.com/meilisearch/meilisearch-migration/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-informational" alt="License"></a>
</p>

<p align="center">MeiliSearch script to update version and migrate data.</p>

**MeiliSearch Version Migration Script** is a script that migrates your MeiliSearch from a version to another more recent version without losing data nor settings.

**MeiliSearch** is an open-source search engine. [Discover what MeiliSearch is!](https://github.com/meilisearch/MeiliSearch)

## Table of Contents <!-- omit in toc -->

- [☝️ Requirements](#-Requirements)
- [🚗 Usage](#-Usage)
- [🎉 Features](#-features)
- [💔 Incompatible Versions](#-version-incompatibilities)
- [📖 Documentation](#-documentation)
- [⚙️ Development Workflow and Contributing](#️-development-workflow-and-contributing)

## ☝️ Requirements

### 1. Systemctl

Currently the script only works in an environment in which MeiliSearch is running as a `systemctl` service.

### 2. Correct data.ms path

The MeiliSearch's `data.ms` must be stored at the following address: `/var/lib/meilisearch/data.ms`.<br>
To ensure this is the case, MeiliSearch should have started with the following flags:`--db-path /var/lib/meilisearch/data.ms`

You can check the information by looking at the file located here `cat /etc/systemd/system/meilisearch.service`.<br>
You should find a line with the specific command used.

```bash
ExecStart=/usr/bin/meilisearch --db-path /var/lib/meilisearch/data.ms --env production
```

By default all MeiliSearch instances created using one of our cloud providers are storing `data.ms` in this repository.

### 3. A Running MeiliSearch instance

A MeiliSearch instance should be running before launching the script. This can be checked using the following command:

```bash
systemctl status meilisearch
```

If you don't have a running MeiliSearch instance, you can create one using one of our Cloud Providers:

| Cloud Provider | Project                                                                              |
| -------------- | :----------------------------------------------------------------------------------- |
| DigitalOcean   | [meilisearch-digitalocean](https://github.com/meilisearch/meilisearch-digitalocean/) |
| AWS            | [meilisearch-aws](https://github.com/meilisearch/meilisearch-aws/)                   |
| GCP            | [meilisearch-gcp](https://github.com/meilisearch/meilisearch-gcp/)                   |

<br>

Alternatively, by [downloading and running MeiliSearch](https://docs.meilisearch.com/learn/getting_started/installation.html#download-and-launch) on your own server and start it as a [systemctl service](https://www.freedesktop.org/software/systemd/man/systemctl.html).

## 🚗 Usage

⚠️ In case of failure during the execution of the script and for security purposes, we strongly recommend [creating manually your own dump](https://docs.meilisearch.com/reference/features/dumps.html#creating-a-dump).

To launch the script you should open the server using SSH and run the following command:

```bash
sh update_meilisearch_version meilisearch_version
```

- `meilisearch_version`: the MeiliSearch version formatted like this: `vX.X.X`

### Example:

An official release:

```bash
sh update_meilisearch_version.sh v0.22.0
```

A release candidate:

```bash
sh update_meilisearch_version.sh v0.22.0rc1
```

![](../../assets/version_update.gif)

## 🎉 Features

- [Automatic Dumps](#automatic-dumps) export and import in case of version incompatibility.
- [Rollback](Rollback in case of failure) in case of failure.

### Automatic Dumps

The script is made to migrate the data properly in case the required version is not compatible with the current version.

It is done by doing the following:

- Create a dump
- Stop MeiliSearch service
- Download and update MeiliSearch
- Start MeiliSearch
- If the start fails because versions are not compatible:
  - Delete current `data.ms`
  - Import the previously created dump
  - Restart MeiliSearch
- Remove generated dump file.

### Rollback in case of failure

If something goes wrong during the version update process a rollback occurs:

- The script rolls back to the previous MeiliSearch version by using the previous cached MeiliSearch binary.
- The previous `data.ms` is used and replaces the new one to ensure MeiliSearch works exactly as before the script was used.
- MeiliSearch is started again.

Example:
Your current version is `v0.21.0` you want to update MeiliSearch to `v0.22.0`. Thus inside your server you import and launch the script

```
sh update_meilisearch_version.sh v0.22.0
```

The migration fails for whatever reason. The script uses the cached `v0.21.0` binary and the cached `data.ms` of the previous version to rollback to its original state.

## 💔 Version incompatibilities

Incompatibility between versions happens in some specific cases. The breaking changes should be described in the CHANGELOG of the release.

In this case, an error will be thrown by MeiliSearch and the script will roll back to the version of MeiliSearch before launching the script.

In order to do the update to the next version, you'll have to manually:

- Export your data without using the dumps, for example by browsing your documents using [this route](https://docs.meilisearch.com/reference/api/documents.html#get-documents).
- Download and launch the binary corresponding to the new version of MeiliSearch.
- Re-index your data and the new settings in the new MeiliSearch instance.

## 📖 Documentation

See our [Documentation](https://docs.meilisearch.com/learn/tutorials/getting_started.html) or our [API References](https://docs.meilisearch.com/reference/api/).

## ⚙️ Development Workflow and Contributing

Any new contribution is more than welcome in this project!

If you want to know more about the development workflow or want to contribute, please visit our [contributing guidelines](/CONTRIBUTING.md) for detailed instructions!

<hr>

**MeiliSearch** provides and maintains many **SDKs and Integration tools** like this one. We want to provide everyone with an **amazing search experience for any kind of project**. If you want to contribute, make suggestions, or just know what's going on right now, visit us in the [integration-guides](https://github.com/meilisearch/integration-guides) repository.

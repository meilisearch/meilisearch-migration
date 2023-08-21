<p align="center">
  <img src="https://github.com/meilisearch/integration-guides/blob/main/assets/logos/logo.svg" alt="Meilisearch Version Update Script" width="200" height="200" />
</p>

<h1 align="center">Meilisearch Version Migration Script</h1>

<h4 align="center">
  <a href="https://github.com/meilisearch/meilisearch">Meilisearch</a> |
  <a href="https://www.meilisearch.com/docs">Documentation</a> |
  <a href="https://discord.meilisearch.com">Discord</a> |
  <a href="https://roadmap.meilisearch.com/tabs/1-under-consideration">Roadmap</a> |
  <a href="https://www.meilisearch.com">Website</a> |
  <a href="https://www.meilisearch.com/docs/faq">FAQ</a>
</h4>

<p align="center">
  <a href="https://github.com/meilisearch/meilisearch-migration/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-informational" alt="License"></a>
</p>

---

🚨 IMPORTANT NOTICE: Reduced Maintenance & Support 🚨

*Dear Community,*

*We'd like to share some updates regarding the future maintenance of this repository:*
*Our team is small, and our availability will be reduced in the upcoming times. As such, response times might be slower, and less frequent updates can be expected.*
*If you're looking for reliable alternatives, consider using [Cloud Service](https://www.meilisearch.com/pricing?utm_campaign=oss&utm_source=integration&utm_medium=docs-scraper). It offers a robust solution for those seeking an alternative to this repository.*
*Seeking Immediate Support? While our presence here may be diminished, we're still active on [our Discord channel](https://discord.meilisearch.com). If you require a quick response for support or any other matters, please join us on [Discord](https://discord.meilisearch.com).*

*We deeply appreciate your understanding and support over the years. The community has been instrumental to our project's success, and we hope you continue to find value in what we've built together. We encourage everyone to support each other, share knowledge, and possibly even contribute to the project if you feel inclined.*

---

<p align="center">🦜 Meilisearch script to update version and migrate data 🦜</p>

**Meilisearch Version Migration Script** is a script that migrates your Meilisearch from a version, v.0.22.0 or higher, to a newer version without losing data nor settings.

**Meilisearch** is an open-source search engine. [Discover what Meilisearch is!](https://github.com/meilisearch/meilisearch)

## Table of Contents <!-- omit in toc -->

- [☝️ Requirements](#-requirements)
- [🚗 Usage](#-usage)
- [🎉 Features](#-features)
- [💔 Incompatible Versions](#-version-incompatibilities)
- [📖 Documentation](#-documentation)
- [🤖 Compatibility with Meilisearch](#-compatibility-with-meilisearch)
- [⚙️ Development Workflow and Contributing](#️-development-workflow-and-contributing)

## ☝️ Requirements

### 1. Systemctl

Currently the script only works in an environment in which Meilisearch is running as a `systemctl` service.

### 2. Correct data.ms path

The Meilisearch's `data.ms` must be stored at the following path: `/var/lib/meilisearch/data.ms`.<br>
To ensure this is the case, Meilisearch should have started with the following flags: `--db-path /var/lib/meilisearch/data.ms`

You can check the information by looking at the file located here `cat /etc/systemd/system/meilisearch.service`.<br>
You should find a line with the specific command used.

```bash
ExecStart=/usr/bin/meilisearch --db-path /var/lib/meilisearch/data.ms --env production
```

By default all Meilisearch instances created using one of our cloud providers are storing `data.ms` in this directory.

### 3. A Running Meilisearch instance

A Meilisearch instance with a version greater than v0.21 should be running before launching the script. This can be checked using the following command:

```bash
systemctl status meilisearch
```

If you don't have a running Meilisearch instance, you can create one using one of our Cloud Providers:

| Cloud Provider | Project                                                                              |
| -------------- | :----------------------------------------------------------------------------------- |
| DigitalOcean   | [meilisearch-digitalocean](https://github.com/meilisearch/meilisearch-digitalocean/) |
| AWS            | [meilisearch-aws](https://github.com/meilisearch/meilisearch-aws/)                   |
| GCP            | [meilisearch-gcp](https://github.com/meilisearch/meilisearch-gcp/)                   |

<br>

Alternatively, by [downloading and running Meilisearch](https://www.meilisearch.com/docs/learn/getting_started/installation) on your own server and start it as a [systemctl service](https://www.freedesktop.org/software/systemd/man/systemctl.html).

## 🚗 Usage

⚠️ In case of failure during the execution of the script and for security purposes, we strongly recommend [creating manually your own dump](https://www.meilisearch.com/docs/learn/advanced/dumps#creating-a-dump). After creating a dump, the file is located at `/dumps` at the root of the server.

Download the script on your Meilisearch server: 

```bash
curl https://raw.githubusercontent.com/meilisearch/meilisearch-migration/main/scripts/update_meilisearch_version.sh --output migration.sh --location
```

To launch the script you should open the server using SSH and run the following command:

```bash
bash migration.sh meilisearch_version
```

- `meilisearch_version`: the Meilisearch version formatted like this: `vX.X.X`

**Note**

If you want to run the script from an AWS instance and you are logged in as `admin`, you probably have to use this command instead:
```bash
sudo -E bash migration.sh meilisearch_version
```

If you want to run the script from a GCP VM instance and you are logged in as a user, you probably have to set the $MEILISEARCH_MASTER_KEY like:
```bash
export MEILISEARCH_MASTER_KEY=YOUR_API_KEY
```
Then run the command line as sudo:
```bash
sudo bash migration.sh meilisearch_version
```

### Example:

An official release:

```bash
bash migration.sh v0.24.0
```

A release candidate:

```bash
bash migration.sh v0.24.0rc1
```

![](../../assets/version_update.gif)

## 🎉 Features

- [Automatic Dumps](#automatic-dumps) export and import in case of version incompatibility.
- [Rollback](#rollback-in-case-of-failure) in case of failure.

### Automatic Dumps

The script is made to migrate the data properly in case the required version is not compatible with the current version.

It is done by doing the following:

- Create a dump
- Stop Meilisearch service
- Download and update Meilisearch
- Start Meilisearch
- If the start fails because versions are not compatible:
  - Delete current `data.ms`
  - Import the previously created dump
  - Restart Meilisearch
- Remove generated dump file.

### Rollback in case of failure

If something goes wrong during the version update process a rollback occurs:

- The script rolls back to the previous Meilisearch version by using the previous cached Meilisearch binary.
- The previous `data.ms` is used and replaces the new one to ensure Meilisearch works exactly as before the script was used.
- Meilisearch is started again.

Example:
Your current version is `v0.23.0` you want to update Meilisearch to `v0.24.0`. Thus inside your server you import and launch the script

```
bash migration.sh v0.24.0
```

The migration fails for whatever reason. The script uses the cached `v0.23.0` binary and the cached `data.ms` of the previous version to rollback to its original state.

## 💔 Version incompatibilities

Versions that are lower than the v0.22.0 can not be migrated. 

It may also happen that versions are incompatible with each other in some specific cases. The breaking changes are described in the CHANGELOG of the release.

In this case, an error will be thrown by Meilisearch and the script will roll back to the version of Meilisearch before launching the script.

In order to do the update to the next version, you'll have to manually:

- Export your data without using the dumps, for example by browsing your documents using [this route](https://www.meilisearch.com/docs/reference/api/documents#get-documents).
- Download and launch the binary corresponding to the new version of Meilisearch.
- Re-index your data and the new settings in the new Meilisearch instance.

## 📖 Documentation

See our [Documentation](https://www.meilisearch.com/docs/learn/getting_started/quick_start) or our [API References](https://www.meilisearch.com/docs/reference/api/overview).

## 🤖 Compatibility with Meilisearch

This package guarantees compatibility with [version v1.x of Meilisearch](https://github.com/meilisearch/meilisearch/releases/latest), but some features may not be present. Please check the [issues](https://github.com/meilisearch/meilisearch-migration/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22+label%3Aenhancement) for more info.

## ⚙️ Development Workflow and Contributing

Any new contribution is more than welcome in this project!

If you want to know more about the development workflow or want to contribute, please visit our [contributing guidelines](/CONTRIBUTING.md) for detailed instructions!

<hr>

**Meilisearch** provides and maintains many **SDKs and Integration tools** like this one. We want to provide everyone with an **amazing search experience for any kind of project**. If you want to contribute, make suggestions, or just know what's going on right now, visit us in the [integration-guides](https://github.com/meilisearch/integration-guides) repository.

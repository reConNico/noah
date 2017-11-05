# noah ~ Automated Rebuilds for [ArkEcosystem/ark-node](https://github.com/ArkEcosystem/ark-node)

> `noah` is still in its early stages which means it is undergoing constant changes so make sure to check the commit history for any changes before updating **AND** test it on devnet before deploying it to mainnet.

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/faustbrian/noah.git
```

### 2. Install noah

> This step is required to guarantee that noah can execute all `sudo` commands required to rebuild your node without your intervention.

```bash
bash ~/noah/noah.sh --install
```

### 3. Start noah

```bash
bash ~/noah/noah.sh --start
```

## Configuration

If you wish to use a different configuration then the default one you will need to open `~/noah/noah.conf` and change it to suit your needs.

### E-Mail

If you wish to use **EMAIL** as your notification driver you will need to install and configure [Postfix](https://digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-on-ubuntu-16-04).

### SMS

If you wish to use **SMS** as your notification driver you will need to sign up for [Nexmo](https://nexmo.com).

### Pushover

If you wish to use **Pushover** as your notification driver you will need to sign up for [Pushover](https://pushover.net).

### Slack

If you wish to use **Slack** as your notification driver you will need to install and configure [slacktee](https://github.com/course-hero/slacktee).

## Commands

```bash
Usage: noah.sh [options]
options:
    help                      Show this help.
    version                   Show the current version.
    start                     Start the noah process.
    stop                      Stop the noah process.
    restart                   Restart the noah process.
    rebuild                   Start the rebuild process.
    monitor                   Temporarily monitor the log.
    install                   Setup noah interactively.
    update                    Update the noah installation.
    log                       Show the noah log.
    test [method] [params]    Test the specified method.
    alias                     Create a bash alias for noah.
```

Run `ps ax | grep '/home/ark/noah/noah.sh' && ps ax | grep '~/noah/noah.sh'` and make sure there are only 2 processes related to the `noah.sh`.

## Security

If you discover a security vulnerability within this package, please send an e-mail to Brian Faust at hello@brianfaust.me. All security vulnerabilities will be promptly addressed.

## Credits

- [Brian Faust](https://github.com/faustbrian)
- [Dafty](https://github.com/dafty)
- [All Contributors](../../contributors)

## License

[MIT](LICENSE) © [Brian Faust](https://brianfaust.me)

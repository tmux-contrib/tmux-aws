# tmux-aws

A `tmux` plugin to style `tmux` windows based on an AWS profile.

## Dependencies

This plugin depends on the following tools. Please make sure they are installed
and available in your `PATH`:

- [aws-cli](https://aws.amazon.com/cli/)

## Installation

Add this plugin to your `~/.tmux.conf`:

```tmux
set -g @plugin 'tmux-contrib/tmux-aws'
```

And install it by running `<prefix> + I`.

## Usage

This plugin provides a script to style the current `tmux` window based on a
specific AWS profile.

### Styling the Current Window

You can call the `scripts/tmux-aws.sh` script with the `--profile` option and
the desired profile name.

```sh
/path/to/tmux-aws/scripts/tmux-aws.sh --profile my-dev-profile
```

This is useful for `tmux` plugins like [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) which can save and restore your sessions. You can have it run this script to style your windows correctly on restore. You can also integrate it with other scripts to automatically style windows when you switch profiles.

### Window Styling

The plugin automatically styles the `tmux` window status based on the
`environment` tag of the selected profile.

It sets the `window-status-current-format` and `window-status-format` to
display an AWS icon (``) and a color indicating the environment.

### AWS Profile Configuration

To enable environment-specific styling, add an `environment` tag to your
profiles in `~/.aws/config`:

```ini
[profile my-dev-profile]
environment = dev

[profile my-stage-profile]
environment = staging

[profile my-prod-profile]
environment = production
```

The script uses partial matching to determine the environment from this tag:

- `dev`: yellow
- `stage`: peach
- `prod`: red

If no matching environment is found, a default color is used.

### Window Variable

The plugin sets a window option `@AWS_PROFILE` with the name of the selected
AWS profile. You can use this in your `tmux` configuration. For example, to
display the profile name in the status line:

```tmux
set -g status-right '#{@AWS_PROFILE}'
```

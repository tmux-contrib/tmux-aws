# Tmux AWS

This is a tmux plugin that provides a set of scripts to manage AWS profiles and credentials within tmux.

## Installation

1.  Add the plugin to your tmux configuration file (`~/.tmux.conf`):

    ```tmux
    set -g @plugin 'tmux-contrib/tmux-aws'
    ```

2.  Install the plugin by running `<prefix> + I`.

3.  This plugin depends on the following tools. Please make sure they are installed and available in your `PATH`:
    *   [aws-vault](https://github.com/99designs/aws-vault)
    *   [fzf](https://github.com/junegunn/fzf)

## Usage

This plugin provides a single script to create a new tmux window with the desired AWS profile activated.

To use it, bind the `scripts/open_window.sh` script to a key in your `~/.tmux.conf`. For example:

```tmux
bind C-a run-shell /path/to/tmux-aws/scripts/open_window.sh
```

Now, when you press `C-a`, a new tmux window will be created, and you will be prompted to select an AWS profile. Once you select a profile, the window will be created with the corresponding AWS credentials activated.

The plugin will also style the tmux window status based on the environment type of the selected profile.

## Configuration

You can configure the environment type for each profile in your AWS config file (`~/.aws/config`):

```ini
[profile my-profile]
environment = development
```

The environment type is used to determine the color of the window status. The following environment types are supported:

*   `development` (yellow)
*   `stage` (peach)
*   `production` (red)

If the environment type is not specified, it will default to `development`.

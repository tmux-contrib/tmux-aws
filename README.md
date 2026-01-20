# tmux-aws

A `tmux` plugin to style `tmux` windows based on an AWS profile.

## Dependencies

### Required
- [aws-cli](https://aws.amazon.com/cli/)

### Optional
- [aws-fzf](https://github.com/aws-contrib/aws-fzf) - Enables interactive AWS profile selection
- [tmux-fzf](https://github.com/sainnhe/tmux-fzf) - Integrates with unified fzf menu

## Installation

Add this plugin to your `~/.tmux.conf`:

```tmux
set -g @plugin 'tmux-contrib/tmux-aws'
```

And install it by running `<prefix> + I`.

### Optional: Interactive Profile Selection

For interactive AWS profile selection, install [aws-fzf](https://github.com/aws-contrib/aws-fzf):

```bash
git clone https://github.com/aws-contrib/aws-fzf.git
cd aws-fzf && make install
```

Once installed, tmux-aws will automatically enable interactive profile selection.

## Usage

### Interactive Profile Selection (with aws-fzf)

When aws-fzf is installed, tmux-aws provides interactive AWS profile selection:

- `Prefix + f + a` → Opens AWS profile picker in fzf menu

**Keybindings in picker:**
- `Enter` → Select profile (displays profile info)
- `alt-c` → Create new window with selected profile
- `alt-C` → Create new session with selected profile
- `alt-s` → Authenticate current session with selected profile
- `alt-w` → Authenticate current window with selected profile

**Configuration:**

```tmux
# fzf menu prefix key (default: f)
set -g @fzf-prefix-key 'f'

# AWS picker key within fzf menu (default: a)
set -g @fzf-aws-key 'a'
```

**Note:** If you also have [tmux-fzf](https://github.com/sainnhe/tmux-fzf) installed, the AWS picker will be available alongside other fzf menu items (projects, sessions, etc.).

### Manual Profile Selection

You can also call the `scripts/tmux_aws.sh` script directly with the `--profile` option:

```sh
# Create new window
/path/to/tmux-aws/scripts/tmux_aws.sh new-window --profile my-dev-profile

# Create new session
/path/to/tmux-aws/scripts/tmux_aws.sh new-session --profile my-dev-profile

# Authenticate current session
/path/to/tmux-aws/scripts/tmux_aws.sh auth-session --profile my-dev-profile

# Authenticate current window
/path/to/tmux-aws/scripts/tmux_aws.sh auth-window --profile my-dev-profile
```

This is useful for integrating with other tools like [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum).

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

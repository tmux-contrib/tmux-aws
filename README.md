# tmux-aws

A `tmux` plugin that exposes AWS profile context as a tmux variable. Pure data passthrough - you control all styling and parsing.

## Dependencies

### Required

- [aws-cli](https://aws.amazon.com/cli/)
- [aws-vault](https://github.com/99designs/aws-vault) (or compatible credential provider)

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

## Variables

The plugin exposes three variables for flexible scoping:

### @aws_profile

The active AWS profile name (raw string, no processing). Set at both session and window levels.

**Scope**:
- `auth-session` or `new-session`: Sets session-level
- `auth-window` or `new-window`: Sets window-level

**Precedence**: Window-level overrides session-level when accessed from window context.

**Use when**: You want automatic fallback (window-level first, then session-level).

```tmux
# Shows window-level if set, otherwise session-level
set -g status-right 'AWS: #{@aws_profile}'
```

### @aws_profile_window

Only set by window-level auth commands. Never falls back to session-level.

**Use when**: You want to show AWS profile ONLY for windows with window-specific auth, ignoring session-wide profile.

```tmux
# Only shows if this specific window has window-level auth
set -g window-status-format '#I:#W #{?@aws_profile_window,  #{@aws_profile_window},}'
```

### @aws_profile_session

Only set by session-level auth commands. Never overridden by window-level.

**Use when**: You want to show session-wide AWS profile in status bar, separate from window-specific profiles.

```tmux
# Shows session-wide profile only
set -g status-left '#{@aws_profile_session} | '
```

### Quick Reference

| Variable | Set by | Falls back | Use case |
|----------|--------|------------|----------|
| `@aws_profile` | Both | Yes (window → session) | General use, automatic fallback |
| `@aws_profile_window` | Window only | No | Window-specific profiles only |
| `@aws_profile_session` | Session only | No | Session-wide profile only |

## Credential Expiration

When using temporary credentials (via aws-vault or similar tools), the plugin can display time-to-live (TTL) information if the `AWS_CREDENTIAL_EXPIRATION` environment variable is set.

### Variables

The plugin exposes three TTL variables following the same scoping pattern as profile variables:

#### @aws_credential_ttl

Shows the time remaining until credentials expire (raw string, human-readable format). Set at both session and window levels.

**Scope**:
- `auth-session` or `new-session`: Sets session-level
- `auth-window` or `new-window`: Sets window-level

**Precedence**: Window-level overrides session-level when accessed from window context.

**Format**: Uses adaptive display based on time remaining (most compact representation):
- `>= 24 hours`: `2d 5h` (days and hours only)
- `1-24 hours`: `6h 45m` (hours and minutes only)
- `1-60 minutes`: `30m 15s` (minutes and seconds)
- `< 1 minute`: `45s` (seconds only)
- `Expired`: `EXPIRED`

**Examples**:
- 2 days, 5 hours remaining → `2d 5h`
- 6 hours, 45 minutes remaining → `6h 45m`
- 30 minutes, 15 seconds remaining → `30m 15s`
- 45 seconds remaining → `45s`
- Expired credentials → `EXPIRED`

**Use when**: You want automatic fallback (window-level first, then session-level).

```tmux
# Shows window-level TTL if set, otherwise session-level
set -g status-right 'AWS: #{@aws_profile} [#{@aws_credential_ttl}]'
```

#### @aws_credential_ttl_window

Only set by window-level auth commands. Never falls back to session-level.

**Use when**: You want to show TTL ONLY for windows with window-specific auth, ignoring session-wide credentials.

```tmux
# Only shows if this specific window has window-level auth
set -g window-status-format '#I:#W #{?@aws_credential_ttl_window,[#{@aws_credential_ttl_window}],}'
```

#### @aws_credential_ttl_session

Only set by session-level auth commands. Never overridden by window-level.

**Use when**: You want to show session-wide credential expiration in status bar, separate from window-specific credentials.

```tmux
# Shows session-wide TTL only
set -g status-left '#{@aws_profile_session} [#{@aws_credential_ttl_session}] | '
```

### Quick Reference

| Variable | Set by | Falls back | Use case |
|----------|--------|------------|----------|
| `@aws_credential_ttl` | Both | Yes (window → session) | General use, automatic fallback |
| `@aws_credential_ttl_window` | Window only | No | Window-specific TTL only |
| `@aws_credential_ttl_session` | Session only | No | Session-wide TTL only |

### Important Notes

- **Static Display**: TTL is calculated once when credentials are loaded, not updated dynamically
- **Availability**: TTL variables are only set when `AWS_CREDENTIAL_EXPIRATION` is present in the environment
- **Adaptive Format**: Display automatically adjusts based on time remaining (shows most relevant units)
- **Scope Pattern**: TTL variables follow the same scoping behavior as `@aws_profile*` variables

### Example: Complete Status Bar with TTL

```tmux
# Show profile and TTL in status bar
set -g status-right 'AWS: #{@aws_profile} [#{@aws_credential_ttl}] | %H:%M'

# Color status bar based on TTL (advanced)
if-shell '[ "$(tmux show-option -gqv @aws_credential_ttl)" = "EXPIRED" ]' \
    'set -g status-style "fg=white,bg=red,bold"'
```

## Commands

All commands work unchanged from v1.x:

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

## Usage Examples

The plugin only sets `@aws_profile`. Here's how to use it for styling and parsing:

### Example 1: Simple Status Bar

Just show the profile:

```tmux
set -g status-right 'AWS: #{@aws_profile}'
```

### Example 2: Parse Environment from Profile Name

Color status bar based on profile name patterns:

```tmux
# Red for production profiles
if-shell '[ -n "$(tmux show-option -gqv @aws_profile | grep -i prod)" ]' \
    'set -g status-style "fg=white,bg=red,bold"'

# Yellow for dev profiles
if-shell '[ -n "$(tmux show-option -gqv @aws_profile | grep -i dev)" ]' \
    'set -g status-style "fg=black,bg=yellow"'

# Orange for staging profiles
if-shell '[ -n "$(tmux show-option -gqv @aws_profile | grep -i stage)" ]' \
    'set -g status-style "fg=black,bg=colour208"'
```

### Example 3: Window Status with Profile Indicator

Show AWS icon + profile in window status:

```tmux
# Show AWS icon and profile in window status
set -g window-status-format '#I:#W #{?@aws_profile,  #{@aws_profile},}'
set -g window-status-current-format '#I:#W #{?@aws_profile,  #{@aws_profile},}'
```

### Example 4: Conditional Window Styling

Color current window based on profile:

```tmux
# This example uses Catppuccin theme colors, but any colors work

if-shell '[ -n "$(tmux show-window-option -qv @aws_profile | grep -i prod)" ]' \
    'set -g window-status-current-style "fg=#{@thm_bg},bg=#{@thm_red},bold"'

if-shell '[ -n "$(tmux show-window-option -qv @aws_profile | grep -i dev)" ]' \
    'set -g window-status-current-style "fg=#{@thm_bg},bg=#{@thm_yellow},bold"'
```

### Example 5: Advanced - Extract Environment from AWS Config

If you tag profiles with 'environment' in `~/.aws/config`:

```ini
[profile my-prod]
environment = production

[profile my-dev]
environment = development
```

You can parse it in tmux.conf:

```tmux
# Parse environment tag from AWS config
set -g @my_aws_env "#(aws configure get environment --profile $(tmux show-option -gqv @aws_profile) 2>/dev/null || echo 'none')"

# Then use it for styling
set -g status-right 'AWS: #{@aws_profile} [#{@my_aws_env}]'
```

### Example 6: Replicate v1.x Default Styling

For users who want the old auto-styling behavior:

```tmux
# Helper function to get color based on profile
set -g @my_aws_color "#(profile=$(tmux show-option -gqv @aws_profile); \
  case $profile in \
    *dev*) echo '@thm_yellow' ;; \
    *stage*) echo '@thm_peach' ;; \
    *prod*) echo '@thm_red' ;; \
    *) echo '@thm_rosewater' ;; \
  esac)"

# Apply window styling (approximates v1.x behavior)
set -g window-status-style 'fg=#{@my_aws_color},bg=#{@thm_bg},nobold'
set -g window-status-current-style 'fg=#{@thm_bg},bg=#{@my_aws_color},nobold'
set -g window-status-format ' #I:   #W #F '
set -g window-status-current-format ' #I:   #W #F '
```

## Configuration

### Custom Credential Provider

By default, tmux-aws uses [aws-vault](https://github.com/99designs/aws-vault) for credential management. You can configure a different tool that implements the aws-vault interface:

```tmux
# Use aws-vault (default)
set -g @tmux-aws-vault-path 'aws-vault'

# Use custom wrapper
set -g @tmux-aws-vault-path 'my-vault-wrapper'
```

**aws-vault interface:** Any tool configured must implement this interface:

```bash
<tool> exec <profile> -- <command>
```

### Variable Capture Pattern

Configure which environment variables to capture:

```tmux
# Capture only AWS_* variables (default)
set -g @tmux-aws-env-regex '^AWS_'

# Capture AWS_*, TF_*, and HSDK_* variables
set -g @tmux-aws-env-regex '^(AWS_|TF_)'
```

### Example: AWS Vault Wrapper

If you have a company tool like hsdk, create a wrapper script:

```bash
#!/bin/bash
# /usr/local/bin/aws-vault.sh

if [[ "$1" != "exec" ]]; then
    echo "Usage: aws-vault.sh exec <profile> -- <command...>"
    exit 1
fi

profile="$2"
shift 3  # Skip 'exec', profile, '--'

# Load credentials with hsdk
# Your custom logic here

# Execute the command
exec "$@"
```

Make it executable and configure:

```bash
chmod +x /usr/local/bin/aws-vault.sh
```

```tmux
set -g @tmux-aws-vault-path 'aws-vault.sh'
set -g @tmux-aws-env-regex '^(AWS_|TF_)'
```

## License

MIT

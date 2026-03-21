# Theme Name — https://example.com
#
# To create a new theme:
# 1. Copy this file: cp _template.sh my-theme.sh
# 2. Replace hex values with your palette
# 3. Install: npx @cmorenogit/claude-statusline
# 4. Activate: export STATUSLINE_THEME=my-theme
#
# Hex to ANSI: \033[38;2;R;G;Bm  (convert hex to decimal RGB)
# Example: #ff5555 → R=255 G=85 B=85 → \033[38;2;255;85;85m

RST='\033[0m'

# ── Accent colors ────────────────────────────────────
PRIMARY='\033[38;2;R;G;Bm'    # model name, weekly rate icon
SECONDARY='\033[38;2;R;G;Bm'  # context icon

# ── Semantic colors (severity scale) ─────────────────
POSITIVE='\033[38;2;R;G;Bm'   # branch, additions, bars < 50%
NOTICE='\033[38;2;R;G;Bm'     # 5hr rate icon, bars 50-69%
CAUTION='\033[38;2;R;G;Bm'    # extra credits, bars 70-89%
NEGATIVE='\033[38;2;R;G;Bm'   # removals, bars 90%+

# ── Neutral colors (text hierarchy) ──────────────────
TEXT='\033[38;2;R;G;Bm'       # directory name
SUBTEXT='\033[38;2;R;G;Bm'    # duration
OVERLAY='\033[38;2;R;G;Bm'    # reset times
SURFACE='\033[38;2;R;G;Bm'    # separators │, empty bar blocks ░

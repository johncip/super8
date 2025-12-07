johncip: let's move some files so that everything is, as much as possible, under lib/super8.

the design document should move from docs/super8_design.md to  lib/super8/design/design_document.md

the text files in docs/super8_chat_logs should move from docs/super8_chat_logs to lib/super8/design/copilot_chat_logs

I'd like to also change the file extension for each of the chat logs from .txt to .md .



GitHub Copilot: Ran terminal command: mkdir -p /Users/john/Developer***REMOVED***/lib/super8/design/copilot_chat_logs

Ran terminal command: mv /Users/john/Developer***REMOVED***/docs/super8_design.md /Users/john/Developer***REMOVED***/lib/super8/design/design_document.md

Ran terminal command: cd /Users/john/Developer***REMOVED***/docs/super8_chat_logs && for file in *.txt; do mv "$file" "/Users/john/Developer***REMOVED***/lib/super8/design/copilot_chat_logs/${file%.txt}.md"; done

Ran terminal command: rmdir /Users/john/Developer***REMOVED***/docs/super8_chat_logs 2>/dev/null; true

Ran terminal command: ls -la /Users/john/Developer***REMOVED***/lib/super8/design/

Ran terminal command: ls -la /Users/john/Developer***REMOVED***/lib/super8/design/copilot_chat_logs/

Perfect! All files have been reorganized under super8:

**New structure**:
- design_document.md - main design doc
- `lib/super8/design/copilot_chat_logs/*.md` - 5 chat log files (converted from .txt)
- investigate_odbc.rb - investigation script

Everything related to Super 8 is now consolidated under super8, making it easier to eventually extract as a gem if needed.
# Barista Demo
# Run with: vhs demo.tape

Output demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 1200
Set Height 600
Set Theme "Dracula"

Type "# Barista - Statusline for Claude Code"
Enter
Sleep 500ms

Type "echo 'Testing statusline output...'"
Enter
Sleep 300ms

Type@50ms 'echo '"'"'{"workspace":{"current_dir":"/Users/demo/myproject"},"model":{"display_name":"Claude Opus 4.5"},"output_style":{"name":"learning"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":75000}},"cost":{"total_cost_usd":2.50,"total_duration_ms":3600000}}'"'"' | ./barista.sh'
Enter
Sleep 2s

Type ""
Enter
Type "# Interactive installer demo"
Enter
Sleep 500ms

Type "./install.sh --help"
Enter
Sleep 3s

Type ""
Enter
Type "# Check for updates"
Enter
Sleep 300ms

Type "./install.sh --check-update"
Enter
Sleep 3s

Type ""
Enter
Type "# Version info"
Enter
Sleep 300ms

Type "./install.sh --version"
Enter
Sleep 2s

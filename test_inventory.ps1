$cmds = @(
    "SET | FJ-TR-UW | 480 | BATCH-TR-START",
    "FJ-TR-UW | Remove | 40 | BATCH-TR-2402",
    "FS-DH-10P | Add | 50 | Delivered"
)
& "$PSScriptRoot\\inventory.ps1" -Commands $cmds


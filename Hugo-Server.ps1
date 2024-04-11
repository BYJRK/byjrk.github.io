if (Test-Path .\resources) {
    Remove-Item -Recurse -Force .\resources
}
if (Test-Path .\public) {
    Remove-Item -Recurse -Force .\public
}

Start-Process hugo -ArgumentList "server -D --disableFastRender" -NoNewWindow -Wait

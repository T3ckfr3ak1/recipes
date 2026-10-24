import 'dart:io';

final class GithubPublishException implements Exception {
  GithubPublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the GitHub credential Git Credential Manager stored for this Windows user.
///
/// The secret is returned to the caller and is not written to disk.
Future<String> readWindowsGitHubToken() async {
  const script = r'''
$ProgressPreference = "SilentlyContinue"
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinCredRead {
  [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  public static extern bool CredRead(string target, int type, int flags, out IntPtr credential);
  [DllImport("advapi32.dll")]
  public static extern void CredFree(IntPtr credential);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct CREDENTIAL {
    public int Flags;
    public int Type;
    public string TargetName;
    public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public int CredentialBlobSize;
    public IntPtr CredentialBlob;
    public int Persist;
    public int AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
  }
  public static string Read(string target) {
    IntPtr p;
    if (!CredRead(target, 1, 0, out p)) return null;
    try {
      var c = Marshal.PtrToStructure<CREDENTIAL>(p);
      if (c.CredentialBlobSize <= 0 || c.CredentialBlob == IntPtr.Zero) return "";
      var bytes = new byte[c.CredentialBlobSize];
      Marshal.Copy(c.CredentialBlob, bytes, 0, c.CredentialBlobSize);
      return System.Text.Encoding.Unicode.GetString(bytes);
    } finally { CredFree(p); }
  }
}
"@
$secret = [WinCredRead]::Read("git:https://github.com")
if ([string]::IsNullOrEmpty($secret)) { exit 2 }
[Console]::Out.Write($secret.Trim([char]0).Trim())
''';
  final result = await Process.run('powershell.exe', [
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    script,
  ]);
  if (result.exitCode != 0) {
    throw GithubPublishException(
      'GitHub sign-in is missing, so the recipes stayed on this computer.',
    );
  }
  final token = (result.stdout as String).trim().replaceAll('\u0000', '');
  if (token.isEmpty || token.contains('\n') || token.contains(' ')) {
    throw GithubPublishException(
      'GitHub sign-in is missing, so the recipes stayed on this computer.',
    );
  }
  return token;
}

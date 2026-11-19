// electron-builder afterPack hook.
// Without an Apple Developer certificate the packaged app is left unsigned, and
// Apple Silicon Macs refuse to launch unsigned code. An ad-hoc signature is
// enough for the app to run; a real certificate (CSC_LINK / CSC_NAME) takes over
// when one is configured.
const { execFileSync } = require('child_process');
const path = require('path');

exports.default = async function adhocSign(context) {
  if (process.platform !== 'darwin' || context.electronPlatformName !== 'darwin') return;
  if (process.env.CSC_LINK || process.env.CSC_NAME) return;
  const app = path.join(context.appOutDir, `${context.packager.appInfo.productFilename}.app`);
  execFileSync('codesign', ['--force', '--deep', '--sign', '-', app], { stdio: 'inherit' });
  execFileSync('codesign', ['--verify', '--deep', '--strict', app], { stdio: 'inherit' });
};

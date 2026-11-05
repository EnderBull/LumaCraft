// 用 sharp 的 SVG 渲染器生成平台图标，输出与脚本均位于项目中。
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

async function main() {
  const directory = __dirname;
  const app = path.resolve(directory, '../..');
  const svg = await fs.readFile(path.join(directory, 'lumacraft-icon.svg'));
  const png = await sharp(svg).resize(1024, 1024).png().toBuffer();
  await fs.writeFile(path.join(directory, 'lumacraft-icon-1024.png'), png);

  const sizes = [16, 24, 32, 48, 64, 128, 256];
  const images = await Promise.all(sizes.map(size => sharp(svg).resize(size, size).png().toBuffer()));
  const header = Buffer.alloc(6 + sizes.length * 16);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  images.forEach((bytes, index) => {
    const entry = 6 + index * 16;
    header[entry] = sizes[index] === 256 ? 0 : sizes[index];
    header[entry + 1] = header[entry];
    header.writeUInt16LE(1, entry + 4);
    header.writeUInt16LE(32, entry + 6);
    header.writeUInt32LE(bytes.length, entry + 8);
    header.writeUInt32LE(offset, entry + 12);
    offset += bytes.length;
  });
  const ico = Buffer.concat([header, ...images]);
  await fs.writeFile(path.join(directory, 'lumacraft.ico'), ico);
  await fs.writeFile(path.join(app, 'windows/runner/resources/app_icon.ico'), ico);

  const androidSizes = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };
  for (const [density, size] of Object.entries(androidSizes)) {
    const destination = path.join(app, 'android/app/src/main/res', `mipmap-${density}`, 'ic_launcher.png');
    await sharp(svg).resize(size, size).png().toFile(destination);
  }
  const metadata = await sharp(png).metadata();
  if (metadata.width !== 1024 || !metadata.hasAlpha || ico.readUInt16LE(4) !== sizes.length) {
    throw new Error('图标尺寸、透明通道或 ICO 索引校验失败');
  }
  const alpha = await sharp(png).extractChannel(3).raw().toBuffer();
  if (alpha[0] !== 0 || alpha[512 * 1024 + 512] !== 255) {
    throw new Error('图标透明区域校验失败');
  }
  console.log('SVG 已渲染。PNG 1024×1024，ICO 7 个尺寸，Android 5 个密度，透明通道检查通过。');
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});

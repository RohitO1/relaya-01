const Jimp = require('jimp');

async function optimizeImage() {
    const filePath = '../assets/images/bottle.png';
    const image = await Jimp.read(filePath);
    
    // Resize the image to height 300 while keeping aspect ratio
    image.resize(Jimp.AUTO, 300);
    
    await image.writeAsync(filePath);
    console.log('Image successfully optimized and resized!');
}

optimizeImage().catch(console.error);

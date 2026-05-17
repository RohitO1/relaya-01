const fs = require('fs');
const PNG = require('pngjs').PNG;

const filePath = '../assets/images/bottle.png';

fs.createReadStream(filePath)
    .pipe(new PNG({
        filterType: 4
    }))
    .on('parsed', function() {
        let fullyTransparent = 0;
        let partialTransparent = 0;
        let opaque = 0;
        let checkerboard = 0;

        for (let y = 0; y < this.height; y++) {
            for (let x = 0; x < this.width; x++) {
                let idx = (this.width * y + x) << 2;
                let a = this.data[idx+3];
                let r = this.data[idx];
                let g = this.data[idx+1];
                let b = this.data[idx+2];
                
                if (a === 0) {
                    fullyTransparent++;
                } else if (a < 255) {
                    partialTransparent++;
                } else {
                    opaque++;
                    // Check if it looks like a grey/white checkerboard
                    if (Math.abs(r - g) < 10 && Math.abs(g - b) < 10) {
                        if ((r > 190 && r < 210) || (r > 240)) {
                            checkerboard++;
                        }
                    }
                }
            }
        }

        let total = this.width * this.height;
        console.log(`Total pixels: ${total}`);
        console.log(`Fully transparent: ${fullyTransparent} (${((fullyTransparent/total)*100).toFixed(2)}%)`);
        console.log(`Partial transparent: ${partialTransparent} (${((partialTransparent/total)*100).toFixed(2)}%)`);
        console.log(`Opaque: ${opaque} (${((opaque/total)*100).toFixed(2)}%)`);
        console.log(`Potential checkerboard: ${checkerboard} (${((checkerboard/total)*100).toFixed(2)}%)`);
    });

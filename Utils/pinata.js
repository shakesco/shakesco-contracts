const fs = require("fs");
const pinataSDK = require("@pinata/sdk");
require("dotenv").config();

const apiKey = process.env.PINATA_API_KEY;
const apiSecret = process.env.PINATA_API_SECRET;
const pinata = new pinataSDK(apiKey, apiSecret);

const storeToPinata = async (imageLocation) => {
  const imagePath = path.resolve(imageLocation);
  const file = fs.readdirSync(imagePath);
  const resolve = [];
  let readableStreamFile, options;
  for (imagesIndex in file) {
    console.log(`Working on ${file[imagesIndex]}...`);
    readableStreamFile = fs.createReadStream(
      `${imagePath}/${file[imagesIndex]}`
    );
    options = {
      pinataMetadata: {
        name: file[imagesIndex],
      },
    };
    try {
      await pinata
        .pinFileToIPFS(readableStreamFile, options)
        .then((response) => {
          resolve.push(response);
        })
        .catch((e) => console.log(e));
    } catch (e) {
      console.log(e);
    }
  }

  return { resolve, file };
};

async function storeMetadata(metadata) {
  const options = {
    pinataMetadata: {
      name: metadata.name,
    },
  };
  try {
    const response = await pinata.pinJSONToIPFS(metadata, options);
    return response;
  } catch (error) {
    console.log(error);
  }
  return null;
}

module.exports = { storeToPinata, storeMetadata };

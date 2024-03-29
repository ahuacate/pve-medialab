const details = () => ({
  id: 'Tdarr_Plugin_ahuacate_filter_break_stack_if_output_file_exists',
  Stage: 'Pre-processing',
  Name: 'Ahua-Filter break out of plugin stack if output file already exists',
  Type: 'Video',
  Operation: 'Filter',
  Description: `This plugin will check if the output video file already exists, if so, it will skip the file.`,
  Version: '1.00',
  Tags: 'pre-processing,filter',
  Inputs: [],
});

const fs = require('fs');
const path = require('path');

// Function to clean up filenames for matching
const cleanFileName = (response, outputDir, fileName) => {
  // Check if the original fileName exists in the outputDir
  if (fs.existsSync(path.join(outputDir, fileName))) {
    response.processFile = false;
    response.infoLog += `☑File already exists in the output directory: ${fileName}`;
    return response;
  }

  // Initialize cleanedFileNameArray
  response.cleanedFileNameArray = [];

  // Check if it's a TV series with SXXEXX pattern
  const tvSeriesMatch = /(.+?[sS]\d{1,2}[eExX]\d{2})/i.exec(fileName);
  if (tvSeriesMatch) {
    // Extract the matched series name
    const cleanedFileName = `${tvSeriesMatch[1]}`;
    response.infoLog += `TV Series match: ${cleanedFileName}\n`;
    response.cleanedFileNameArray.push(cleanedFileName);
    return response;
  }

  // Check if there's an IMDb ID in square bracketscleanedFileNameArray
  const imdbIdMatch = /\[imdbid-tt(\d+)\]/.exec(fileName);
  if (imdbIdMatch) {
    const cleanedFileName = fileName.replace(/(\[imdbid-tt\d+\]).*$/, '$1').trim();
    // Check if the cleanedFileName includes the TV series pattern
    if (!/(s\d{2}[ex]?\d{2})/i.test(cleanedFileName)) {
      response.cleanedFileNameArray.push(cleanedFileName);
      return response;
    }
  }

  // Check if there's a year in brackets
  const yearMatch = /\((\d{4})\)/.exec(fileName);
  if (yearMatch) {
    const cleanedFileName = fileName.replace(/(\((\d{4})\)).*$/, '$1').trim();
    // Check if the cleanedFileName includes the TV series pattern
    if (!/(s\d{2}[ex]?\d{2})/i.test(cleanedFileName)) {
      response.cleanedFileNameArray.push(cleanedFileName);
      return response;
    }
  }

  // If no matching pattern found, return original fileName to cleanedFileNameArray
  if (response.cleanedFileNameArray.length === 0) {
    response.cleanedFileNameArray.push(fileName.trim());
  }

  return response;
};


// // Function to check if any file in the output directory matches cleanedFileNameArray
// const doesFileExistInOutputDir = (outputDir, cleanedFileNameArray) => {
//   const checkFile = (dir) => {
//     try {
//       const files = fs.readdirSync(dir);
//       for (const file of files) {
//         const filePath = path.join(dir, file);
//         const stat = fs.statSync(filePath);

//         if (stat.isDirectory()) {
//           // Recursively check subdirectories
//           if (checkFile(filePath)) {
//             return true;
//           }
//         } else {
//           // Check if any cleanedFileNameArray entry is a partial match of the current file name (case-insensitive)
//           if (cleanedFileNameArray.some(entry => file.toLowerCase().startsWith(entry.toLowerCase()))) {
//             return true;
//           }
//         }
//       }
//     } catch (error) {
//       console.error(`Error reading directory: ${error.message}`);
//       return false;
//     }

//     return false;
//   };

//   return checkFile(outputDir);
// };

// Check if Ahua transcode plugin already performed and if so break
const hasBeenTranscoded = (file) => {
  // Iterate through the tracks of the file
  for (const track of file.mediaInfo.track) {
      // Check if the track has a 'Comment' field
      if (track.Comment) {
          // Check if the 'Comment' field contains the specified string
          if (track.Comment.match(/ahuacate\.video\.transcode/i)) {
              return true; // File has been transcoded
          }
      }
  }
  return false; // File has not been transcoded
};

// Function to check if any video file in the output directory matches cleanedFileNameArray
const doesFileExistInOutputDir = (outputDir, cleanedFileNameArray, originalExtension) => {
  const videoExtensions = ['.mp4', '.mkv', '.ts', '.avi'];

  const checkFile = (dir) => {
    try {
      const files = fs.readdirSync(dir);
      for (const file of files) {
        const filePath = path.join(dir, file);
        const stat = fs.statSync(filePath);

        if (stat.isDirectory()) {
          // Recursively check subdirectories
          if (checkFile(filePath)) {
            return true;
          }
        } else {
          // Check if the file has a video extension, including the original file extension
          const fileExtension = path.extname(file).toLowerCase();
          if (videoExtensions.includes(fileExtension) || fileExtension === originalExtension) {
            // Check if any cleanedFileNameArray entry is a partial match of the current file name (case-insensitive)
            if (cleanedFileNameArray.some(entry => file.toLowerCase().startsWith(entry.toLowerCase()))) {
              return true;
            }
          }
        }
      }
    } catch (error) {
      console.error(`Error reading directory: ${error.message}`);
      return false;
    }

    return false;
  };

  return checkFile(outputDir);
};


const plugin = (file, librarySettings, inputs, otherArguments) => {
  const lib = require('../methods/lib')();
  
  // Set up required variables.
  let fileName = path.basename(file.file); // gets only the file name
  let outputDir = librarySettings.output; // gets destination folder

  // eslint-disable-next-line no-unused-vars,no-param-reassign
  inputs = lib.loadDefaultValues(inputs, details);

  // Initialize the response object
  const response = {
    processFile: true,
    infoLog: '',
    cleanedFileName: '',
  };


  // Clean up the file name
  cleanFileName(response, outputDir, fileName);

  // Debug line to print the entries
  if (response.cleanedFileNameArray) {
    response.cleanedFileNameArray.forEach(entry => {
      response.infoLog += `☑Checking file existence recursively: ${entry} \n`;
    });
  }
  if (doesFileExistInOutputDir(outputDir, response.cleanedFileNameArray)) {
    response.processFile = false;
    response.infoLog += `☑File already exists in the output directory: ${fileName}`;
  } else {
    response.infoLog += `☑File does not exist in the output directory: ${fileName}`;
  }

  // Check if file has been transcoded
  if (hasBeenTranscoded(file)) {
    response.processFile = false;
    response.infoLog += `☒File has already been transcoded: ${fileName}`;
  } else {
    response.infoLog += `☑File has not been transcoded: ${fileName}`;
  }

  // Always return the response
  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;
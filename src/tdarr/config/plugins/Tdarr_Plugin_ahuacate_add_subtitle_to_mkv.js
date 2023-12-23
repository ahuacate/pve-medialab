/* eslint-disable */


// tdarrSkipTest
const details = () => {
  return {
    id: "Tdarr_Plugin_ahuacate_add_subtitle_to_mkv",
    Stage: "Pre-processing",
    Name: "Add subtitle srt file to MKV files",
    Type: "Video",
    Operation: 'Transcode',
    Description: `This plugin integrates SRT subtitle languages into your Matroska MKV video container. SRT subtitle files should adhere to the iso6391 or iso6392 language format, such as 'filename.eng.srt' or 'filename.en.srt'. The plugin utilizes FFMPEG to include source subtitles in a specific language if they are detected. If no subtitles in the desired language are present, they won't be added. During the initial run, the plugin will install the node modules iso-639-1 and iso-639-2 in your Tdarr application folder.\n`,
    Version: "1.3",
    Tags: "pre-processing,ffmpeg,subtitle only,configurable",
    Inputs: [
      {
        name: 'Subtitle_Languages',
        type: 'string',
        defaultValue: 'eng, en,',
        inputUI: {
          type: 'text',
        },
        tooltip: `Indicate the desired language tags for the SRT files and tracks to be retained. Ensure that your inputs follow the iso6391 and iso6392 two and three-letter code format, as specified in https://en.wikipedia.org/wiki/List_of_ISO_639-2_codes. You have the flexibility to combine both two and three-letter codes. Align your inputs with the language settings in other Tdarr stack subtitle plugins, such as 'Migz-Clean subtitle streams'.
                      \\nExample:\\n
                      eng,en (default)
                      \\nExample:\\n
                      eng,en,jpn`,
      },
      {
        name: 'Install_Packages',
        type: 'boolean',
        defaultValue: true,
        inputUI: {
          type: 'dropdown',
          options: [
            'true',
            'false',
          ],
        },
        tooltip: `Allow the plugin to install the required iso node modules: iso-639-1 and iso-639-2.
                  \\nExample:\\n 
                  true (default)
                  \\nExample:\\n 
                  false`,
      },
    ],
  };
}


// eslint-disable-next-line @typescript-eslint/no-unused-vars
const plugin = (file, librarySettings, inputs, otherArguments) => {
  const lib = require('../methods/lib')();
  const fs = require("fs");
  const path = require('path');
  const os = require('os');
  const execSync = require("child_process").execSync;
  // eslint-disable-next-line @typescript-eslint/no-unused-vars,no-param-reassign
  inputs = lib.loadDefaultValues(inputs, details);
  //default response
  const response = {
    processFile: false,
    preset: `,`,
    container: ".mkv",
    handBrakeMode: false,
    FFmpegMode: false,
    reQueueAfter: false,
    infoLog: `Searching new subtitles...\n`,
  };

  // Set up required variables.
  let i = 0; //int for counting lang[position]
  let found_subtitle_stream = 0;
  let sub = 0; //becomes first subtitle stream
  let originalFilePath = otherArguments.originalLibraryFile.file;  // let fileDirPath = file.meta.Directory; //path of media folder
  let videoFileName = path.parse(originalFilePath).name;  // Get the filename without extension
  let fileDirPath = path.parse(originalFilePath).dir;
  let new_subs = 0; //count the new subs
  let added_subs = 0; //counts the amount of subs that have been mapped
  let preset_import = '';
  let preset_meta = '';
  let iso6391, iso6392;
  

  // Check if the output container type is not "mkv"
  if (file.container.toLowerCase() !== 'mkv') {
    response.infoLog += `Skipping the plugin because the output container type is not MKV.\n`;
    return response;
  }

  // Check if 'inputs.Subtitle_Languages' is empty
  if (!inputs.Subtitle_Languages || !inputs.Subtitle_Languages.trim()) {
    response.infoLog += 'Subtitle languages input is empty. Skipping the plugin.\n';  // Empty. Skip the plugin
    return response;
  }

  // Check if the platform is Linux
  if (os.platform() !== 'linux') {
    response.infoLog += 'This plugin is intended for Linux platforms only. Skipping on this platform.\n';
    return response;
  }

  // Check if Node.js is installed
  try {
    execSync('node -v');
  } catch (error) {
    response.infoLog += 'Node.js is not installed. Please install Node.js to use this plugin.\n';
    return response;
  }

  // Check if npm is installed
  try {
    execSync('npm -v');
  } catch (error) {
    response.infoLog += 'npm is not installed. Please install npm to use this plugin.\n';
    return response;
  }

  // Func - Find Tdarr app dir
  function findTdarrDirPath(startingPath) {
    let currentPath = startingPath;
    while (currentPath !== '/') {
      // Skip search under /mnt
      if (currentPath.startsWith('/mnt')) {
        return null; // Tdarr directory not found under /mnt
      }
      const potentialTdarrPathNode = path.join(currentPath, 'Tdarr_Node');
      const potentialTdarrPathServer = path.join(currentPath, 'Tdarr_Server');
      if (
        (fs.existsSync(potentialTdarrPathNode) && fs.statSync(potentialTdarrPathNode).isDirectory()) ||
        (fs.existsSync(potentialTdarrPathServer) && fs.statSync(potentialTdarrPathServer).isDirectory())
      ) {
        return currentPath;
      }
      currentPath = path.dirname(currentPath);
    }
    return null; // Tdarr directory not found
  }

  // Find and set Tdarr dir
  const tdarrPath = findTdarrDirPath(__dirname);  // Start the search from the directory of the script
  if (tdarrPath) {
    response.infoLog += `Tdarr app dir found: ${tdarrPath}\n`;
  } else {
    response.infoLog += `Tdarr app dir not found. Something is wrong. Skipping this plugin.\n`;
    return response;
  }

  // Install iso6392
  if (inputs.Install_Packages === true && !fs.existsSync(`${tdarrPath}/node_modules/iso-639-2`)) {
      execSync(`cd ${tdarrPath} \n npm install iso-639-2@2.0.0`);
  } else if (inputs.Install_Packages == 'no' && !fs.existsSync(`${tdarrPath}/node_modules/iso-639-2`)) {
    response.infoLog += `Your input to install the required packages is set to false. \n Extra node modules are required. Skipping this plugin.\n`;
    return response;
  }

  // Install iso6391
  if (inputs.Install_Packages === true && !fs.existsSync(`${tdarrPath}/node_modules/iso-639-1`)) {
    execSync(`cd ${tdarrPath} \n npm install iso-639-1@2.0.0`);
  } else if (inputs.Install_Packages == 'no' && !fs.existsSync(`${tdarrPath}/node_modules/iso-639-1`)) {
    response.infoLog += `Your input to install the required packages is set to false. \n Extra node modules are required. Skipping this plugin.\n`;
    return response;
  }

  // Check iso lang installed
  if (fs.existsSync(`${tdarrPath}/node_modules/iso-639-2`)) {
    iso6392 = require(`${tdarrPath}/node_modules/iso-639-2`);
  } else {
    response.infoLog += 'Node module iso-639-2 not found\n';
    return response;
  }
  if (fs.existsSync(`${tdarrPath}/node_modules/iso-639-1`)) {
    iso6391 = require(`${tdarrPath}/node_modules/iso-639-1`);
  } else {
    response.infoLog += 'Node module iso-639-1 not found\n';
    return response;
  }

  // Clean user subtitle language input 'inputs.Subtitle_Languages' (remove spaces etc)
  // Note: missing validation for iso6391/2 compliance
  const lang = inputs.Subtitle_Languages
    .toLowerCase() // Convert to lowercase
    .trim() // Remove leading and trailing spaces
    .replace(/\s*,\s*/g, ',') // Replace spaces around commas with a single comma
    .replace(/^,|,$/g, '') // Remove leading and trailing commas
    .split(',')
    .map(entry => entry.trim().toLowerCase())  // Trim spaces and convert to lowercase
    .filter(entry => /^[a-z]{2,3}$/.test(entry));  // Filter valid entries with ISO 639-1 or ISO 639-2 pattern

  // find first subtitle stream
  while (found_subtitle_stream == 0 && sub < file.ffProbeData.streams.length) {
    if (file.ffProbeData.streams[sub].codec_type.toLowerCase() == "subtitle") {
      found_subtitle_stream = 1;
    } else {
      sub++;
    }
  }

  // Add srt lang subtitles
  for (let i = 0; i < lang.length; i++) {
    const isoCode = lang[i];
    const subtitlePath = path.join(fileDirPath, `${videoFileName}.${isoCode}.srt`);
    response.infoLog += `Checking for subtitle file: ${subtitlePath}\n`;

    // Check if srt file exists in folder
    if (fs.existsSync(subtitlePath)) {
      response.infoLog += `Found subtitle ${isoCode}.srt\n`;

      let languageAlreadyExists = false;

      // Check if language already exists in any stream
      for (let sub_stream = 0; sub_stream < file.ffProbeData.streams.length; sub_stream++) {
        const stream = file.ffProbeData.streams[sub_stream];
        if (stream.codec_type.toLowerCase() === 'subtitle' && stream.tags && stream.tags.language) {
          if (stream.tags.language.toLowerCase() === isoCode) {
            languageAlreadyExists = true;
            response.infoLog += `Language already exists in stream ${sub_stream}\n It will not be added\n`;
            break;
          }
        }
      }

      // Add if the language hasn't been found
      if (!languageAlreadyExists) {
        preset_import += ` -sub_charenc "UTF-8" -f srt -i "${subtitlePath}"`;
        preset_meta += ` -metadata:s:s:${new_subs} language=${isoCode}`;
        new_subs++;
      }
    }
  }
    
  // Add default audio and video
  response.preset += ` ${preset_import}${preset_meta} -map 0:v -map 0:a?`;

  //map new subs
  while (added_subs < new_subs) {
    added_subs++;
    response.preset += ` -map ${added_subs}:s`;
  }

  //if new subs have been found they will be added
  if (new_subs > 0) {
    response.FFmpegMode = true;
    response.processFile = true;
    response.reQueueAfter = true;
    if (found_subtitle_stream === 1) {
      response.preset += ` -map 0:s `;
    }
    response.preset += ` -c copy`;
    // response.preset += ` -c:v copy -c:a copy`;
    response.infoLog += `${new_subs} new subs will be added\n`;
  } else {
    response.infoLog += `No new subtitle languages were found\n`;
  }

  //response.infoLog += `The ffmpeg string is: ${response.preset}\n`

  return response;
}
  
module.exports.details = details;
module.exports.plugin = plugin;
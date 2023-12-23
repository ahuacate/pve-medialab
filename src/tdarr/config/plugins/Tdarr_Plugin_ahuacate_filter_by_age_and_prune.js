const fs = require('fs');
const path = require('path');

const details = () => ({
  id: 'Tdarr_Plugin_ahuacate_filter_by_age_and_prune',
  Stage: 'Pre-processing',
  Name: 'Ahua-Filter and prune files by modified date',
  Type: 'Video',
  Operation: 'Filter',
  Description: `
  This plugin prevents processing files older than preset number of days. \n\n
  The plugin also automatically deletes files older than a specified age from your library output folder. It also deletes empty folders from your library output folder.`,
  Version: '1.00',
  Tags: 'pre-processing,filter,configurable',
  Inputs: [
    // (Optional) Inputs you'd like the user to enter to allow your plugin to be easily configurable from the UI
    {
      name: 'Max_Input_Age_Days',
      type: 'number',
      defaultValue: 14,
      inputUI: {
        type: 'text',
      },
      tooltip: `Specify the number of days for Tdarr to scan for new files based on their modified date. If you input 14, the plugin will only process files modified within the last 14 days. Files older than 14 days will be excluded from processing.
                  \\n Your input value must be less than your 'Min_Prune_Age_Days' value.
                    \\nExample:\\n
                    7
                    \\nExample:\\n
                    14 
                    \\nExample:\\n
                    90`,
    },
    {
      name: 'Min_Prune_Age_Days',
      type: 'number',
      defaultValue: 30,
      inputUI: {
        type: 'text',
      },
      tooltip: `Set the maximum allowable age for files before they are automatically deleted from your output folder, determined by their modified date. If you input 60, the plugin will delete all files in your Tdarr output folder that are older than 60 days. A setting of '0' disables this function.
                  \\nExample:\\n
                  0 (disable prune)
                  \\nExample:\\n
                  90
                  \\nExample:\\n
                  365`,
    },
    {
      name: 'Files_To_Exclude_From_Prune',
      type: 'string',
      defaultValue: 'example.mkv',
      inputUI: {
        type: 'text',
      },
      tooltip: `Specify the names of files you want to exempt from deletion in your output folder. Ensure each entry is separated by a comma (,) and starts and ends with no spaces. By default, ".foo_protect" is excluded.
                  \\nExample:\\n
                  example_file.mov,do not delete me.file`,
    },
    {
      name: 'Dirs_To_Always_Prune',
      type: 'string',
      defaultValue: '@eaDir',
      inputUI: {
        type: 'text',
      },
      tooltip: `Specify the names of dirs you want to always delete in your output folder. These could temporary rubbish bin folders such as '.Trash-1000' and '.recycle'. Ensure each entry is separated by a comma (,) and starts and ends with no spaces. By default, the Synology NAS "@eaDir" is already included.
                  \\nExample:\\n
                  rubbish,.recycle,.Trash-1000`,
    },
  ],
});


// eslint-disable-next-line @typescript-eslint/no-unused-vars
const plugin = (file, librarySettings, inputs, otherArguments) => {
  const lib = require('../methods/lib')();
  // eslint-disable-next-line @typescript-eslint/no-unused-vars,no-param-reassign
  inputs = lib.loadDefaultValues(inputs, details);
  const response = {
    processFile: true,
    infoLog: '',
  };

  // Set up required variables.
  // let fileName = file.file; // sets source file name
  let outputDir = librarySettings.output; // gets destination folder

  // Check if pruning is enabled and validate Min_Prune_Age_Days
  if (inputs.Min_Prune_Age_Days !== 0) {
    if (inputs.Min_Prune_Age_Days <= inputs.Max_Input_Age_Days) {
      inputs.Min_Prune_Age_Days = (inputs.Max_Input_Age_Days + 1).toString();  // Adjust Min_Prune_Age_Days to be at least Max_Input_Age_Days + 1
      response.infoLog += `Adjusted Min_Prune_Age_Days to be greater than Max_Input_Age_Days. New value: ${inputs.Min_Prune_Age_Days}\n`;
    }
  }

  // Assuming inputs.Files_To_Exclude_From_Prune is a string with filenames separated by ','
  const rawFilesToExclude = inputs.Files_To_Exclude_From_Prune;
  const cleanedFilesToExclude = (typeof rawFilesToExclude === 'string' ? rawFilesToExclude : '').trim();  // Remove spaces at the beginning and end of the input string
  const filesToExclude = cleanedFilesToExclude.replace(/,\s*/g, ',');  // Remove spaces after commas
  const filesToExcludeArray = filesToExclude.split(',');  // Split the cleaned string into an array using ',' as the delimiter
  if (!filesToExcludeArray.includes('.foo_protect')) {
    filesToExcludeArray.push('.foo_protect');  // Ensure ".foo_protect" is always included in the array
  }

  // Assuming inputs.Dirs_To_Always_Prune is a string with filenames separated by ','
  const rawDirsToAlwaysDelete = inputs.Dirs_To_Always_Prune;
  const cleanedDirsToAlwaysDelete = (typeof rawDirsToAlwaysDelete === 'string' ? rawDirsToAlwaysDelete : '').trim();  // Remove spaces at the beginning and end of the input string
  const dirsToAlwaysDelete = cleanedDirsToAlwaysDelete.replace(/,\s*/g, ',');  // Remove spaces after commas
  const dirsToAlwaysDeleteArray = dirsToAlwaysDelete.split(',');  // Split the cleaned string into an array using ',' as the delimiter
  if (!dirsToAlwaysDeleteArray.includes('@eaDir')) {
    dirsToAlwaysDeleteArray.push('@eaDir');  // Ensure "@eaDir" is always included in the array
  }

  // Function to prune files older than a specified age from a folder
  const pruneOldFiles = async (outputDir, minAge, filesToExcludeArray) => {
    try {
        const files = await fs.promises.readdir(outputDir);

        for (const file of files) {
            const filePath = path.join(outputDir, file);
            const fileStats = await fs.promises.stat(filePath);

            if (fileStats.isDirectory()) {
                // Recursively process subdirectories
                await pruneOldFiles(filePath, minAge, filesToExcludeArray);
            } else {
                // Check if the current file is in the exclusion list
                if (filesToExcludeArray.includes(file)) {
                    response.infoLog += `Excluding file from deletion: ${file}\n`;
                    continue;
                }

                const fileAge = Date.now() - fileStats.mtimeMs;

                if (fileAge > minAge) {
                    await fs.promises.unlink(filePath);
                    response.infoLog += `Pruned file: ${file}, Age: ${fileAge}\n`;
                }
            }
        }
    } catch (error) {
        response.infoLog += `Error pruning files: ${error}\n`;
    }
  };

  // Function to delete empty folders and folder entries in 'dirsToAlwaysDeleteArray'
  const deleteEmptyFolders = async (outputDir, dirsToAlwaysDeleteArray) => {
    try {
      const files = await fs.promises.readdir(outputDir);
  
      for (const file of files) {
        const filePath = path.join(outputDir, file);
        const fileStat = await fs.promises.stat(filePath);
  
        if (fileStat.isDirectory()) {
          const isAlwaysDeleteFolder = dirsToAlwaysDeleteArray.includes(file);
  
          if (!isAlwaysDeleteFolder) {
            // Recursively process subdirectories
            await deleteEmptyFolders(filePath, dirsToAlwaysDeleteArray);
          }
        } else {
          response.infoLog += `File: ${filePath}\n`;
        }
      }
  
      // Check if the folder is empty or contains only directories to always delete
      const updatedFiles = await fs.promises.readdir(outputDir);
      const containsOnlyIgnoredItems = updatedFiles.every(item => dirsToAlwaysDeleteArray.includes(item));
  
      if (updatedFiles.length === 0 || containsOnlyIgnoredItems) {
        await fs.promises.rmdir(outputDir, { recursive: true });
        const folderName = path.basename(outputDir);  // Extract folder name from the path
        response.infoLog += `Deleted folder: ${folderName}\n`;
      } else {
        const folderName = path.basename(outputDir);  // Extract folder name from the path
        response.infoLog += `Folder not deleted: ${folderName}, Files: ${updatedFiles.join(', ')}\n`;
      }
    } catch (error) {
      response.infoLog += `Error deleting folders: ${error}\n`;
    }
  };

  // Prune files older than 'Min_Prune_Age_Days'
  if (inputs.Min_Prune_Age_Days === 0) {
    response.infoLog += 'Pruning disabled. Moving to the next plugin stage \n';  // Skip pruning if Min_Prune_Age_Days is set to 0
  } else {
    // 
    const pruneAge = Number(inputs.Min_Prune_Age_Days) * 86400000;
    // const pruneFolderPath = librarySettings.output;
    pruneOldFiles(outputDir, pruneAge, filesToExcludeArray);
  }

  // Delete empty folders
  // const deleteFolderPath = librarySettings.output;
  deleteEmptyFolders(outputDir, dirsToAlwaysDeleteArray);

  // Filter input by age 'Max_Input_Age_Days'
  const age = Date.now() - file.statSync.mtimeMs;
  const reqage = Number(inputs.Max_Input_Age_Days) * 86400000;
  if (age < reqage) {
    response.infoLog += 'File modified date young enough. Moving to the next plugin \n';
    response.infoLog += `File age: ${age} \n`;
    response.infoLog += `Required file age: ${reqage} \n`;
    response.infoLog += `Output folder: ${librarySettings.output} \n`;
    response.processFile = true;
  } else {
    response.infoLog += 'File modified date not young enough. Skipping file \n';
    response.infoLog += `File age: ${age} \n`;
    response.infoLog += `Required file age: ${reqage} \n`;
    response.infoLog += `Output folder: ${librarySettings.output} \n`;
    response.processFile = false;
  }

  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;
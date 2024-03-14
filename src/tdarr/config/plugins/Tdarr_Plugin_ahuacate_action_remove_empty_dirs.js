const fs = require('fs');
const path = require('path');

const details = () => ({
  id: 'Tdarr_Plugin_ahuacate_action_remove_empty_dirs',
  Stage: 'Post-processing',
  Name: 'Ahua-Action remove empty, small dirs or folders',
  Type: 'Video',
  Operation: 'Post-processing',
  Description: `
  This plugin removes small and empty folders from your source and output directory. \n\n
  It is designed for the deletion of empty folders containing erroneous left over files, ensuring your directory structure remains clean and organized.`,
  Version: '1.00',
  Tags: 'post-processing',
  Inputs: [
    // (Optional) Inputs you'd like the user to enter to allow your plugin to be easily configurable from the UI
    {
      name: 'Max_Dir_Size',
      type: 'number',
      defaultValue: 1000,
      inputUI: {
        type: 'text',
      },
      tooltip: `Define the maximum folder size to delete. For instance, if you input 1000, the plugin will handle folders within the range from '0Kb' up to '1000Kb', excluding all folders larger than 1000Kb.
                  \\n Your input value must be greater than 0.
                    \\nExample:\\n
                    50
                    \\nExample:\\n
                    100
                    \\nExample:\\n
                    1000`,
    },
  ],
});


// eslint-disable-next-line @typescript-eslint/no-unused-vars
const plugin = async (file, librarySettings, inputs, otherArguments) => {
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
  let inputDir = librarySettings.folder; // path of media folder
  let maxDirSize = inputs.Max_Dir_Size; // Get the value of Max_Dir_Size from the inputs or configuration;

  // Assuming inputs.Files_To_Exclude_From_Prune is a string with filenames separated by ','
  const rawFilesToExclude = inputs.Files_To_Exclude_From_Prune;
  const cleanedFilesToExclude = (typeof rawFilesToExclude === 'string' ? rawFilesToExclude : '').trim();  // Remove spaces at the beginning and end of the input string
  const filesToExclude = cleanedFilesToExclude.replace(/,\s*/g, ',');  // Remove spaces after commas
  const filesToExcludeArray = filesToExclude.split(',');  // Split the cleaned string into an array using ',' as the delimiter
  const alwaysExcludedFiles = [".foo_protect", "*partial*"];  // Ensure file names are always included in the array
  alwaysExcludedFiles.forEach(file => {
    const regex = new RegExp(file.replace(/\*/g, '.*'), 'i');  // Convert * to .* in the regex
    if (!filesToExcludeArray.some(existingFile => regex.test(existingFile))) {
      filesToExcludeArray.push(file);
    }
  });

  // Assuming inputs.Dirs_To_Always_Prune is a string with filenames separated by ','
  const rawDirsToAlwaysDelete = inputs.Dirs_To_Always_Prune;
  const cleanedDirsToAlwaysDelete = (typeof rawDirsToAlwaysDelete === 'string' ? rawDirsToAlwaysDelete : '').trim();  // Remove spaces at the beginning and end of the input string
  const dirsToAlwaysDelete = cleanedDirsToAlwaysDelete.replace(/,\s*/g, ',');  // Remove spaces after commas
  const dirsToAlwaysDeleteArray = dirsToAlwaysDelete.split(',');  // Split the cleaned string into an array using ',' as the delimiter
  const alwaysIncludedDirs = ["@eaDir", "cache", "recycle", "#recycle", ".Trash", "lost+found", ".DS_store", "metadata", "SYNOINDEX_MEDIA_INFO"];  // Ensure dir names are always included in the array
  alwaysIncludedDirs.forEach(dir => {
    if (!dirsToAlwaysDeleteArray.includes(dir)) {
      dirsToAlwaysDeleteArray.push(dir);
    }
  });


  // Function to delete empty folders and folder entries
  const deleteEmptyFolders = async (currentPath, dirsToAlwaysDeleteArray, filesToExcludeArray, maxDirSize) => {
    try {
        const files = await fs.promises.readdir(currentPath);

        // Check if the folder is empty
        if (files.length === 0) {
            await fs.promises.rmdir(currentPath);
            console.log(`Deleted empty folder: ${currentPath}`);
            return;
        }

        // Recursively process subdirectories
        for (const file of files) {
            const filePath = path.join(currentPath, file);
            const fileStat = await fs.promises.stat(filePath);

            if (fileStat.isDirectory()) {
                await deleteEmptyFolders(filePath, dirsToAlwaysDeleteArray, filesToExcludeArray, maxDirSize);
            }
        }

        // Check if the folder is in the list of directories to always delete
        if (dirsToAlwaysDeleteArray.includes(path.basename(currentPath))) {
            await fs.promises.rmdir(currentPath, { recursive: true });
            console.log(`Deleted folder included in the list of directories to always delete: ${currentPath}`);
            return;
        }

        // Check if the folder size is smaller than maxDirSize and not in filesToExcludeArray
        const folderSize = await getFolderSize(currentPath);
        if (folderSize < maxDirSize && !files.some(file => filesToExcludeArray.includes(file))) {
            await fs.promises.rmdir(currentPath, { recursive: true });
            console.log(`Deleted folder smaller than ${maxDirSize}KB and does not contain excluded files: ${currentPath}`);
        }
    } catch (error) {
        console.error(`Error deleting folders: ${error}`);
    }
  };

  // Function to get the size of a folder
  const getFolderSize = async (folderPath) => {
    let size = 0;
    const files = await fs.promises.readdir(folderPath);
    for (const file of files) {
        const filePath = path.join(folderPath, file);
        const fileStat = await fs.promises.stat(filePath);
        size += fileStat.size;
    }
    return size / 1024; // Convert bytes to kilobytes
  };

  // Call deleteEmptyFolders for each path
  await deleteEmptyFolders(outputDir, dirsToAlwaysDeleteArray, filesToExcludeArray, maxDirSize);
  await deleteEmptyFolders(inputDir, dirsToAlwaysDeleteArray, filesToExcludeArray, maxDirSize);

  // Set response.processFile to false after both functions have completed
  response.processFile = false;

  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;
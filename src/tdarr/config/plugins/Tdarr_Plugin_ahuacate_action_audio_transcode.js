/* eslint no-plusplus: ["error", { "allowForLoopAfterthoughts": true }] */
const details = () => ({
  id: 'Tdarr_Plugin_ahuacate_action_audio_transcode',
  Stage: 'Pre-processing',
  Name: 'Ahua-Transcode a audio file',
  Type: 'Audio',
  Operation: 'Transcode',
  Description: `This plugin consolidates audio tracks into a single unified track and converts the audio to the desired format. It packages the single audio track within the video file container, aiming to minimize the size of the video container. \n\n`,
  Version: '1.0',
  Tags: 'pre-processing,ffmpeg,audio only,configurable',
  Inputs: [
    {
      name: 'target_audio_channels',
      type: 'string',
      defaultValue: '2.0',
      inputUI: {
        type: 'dropdown',
        options: [
          '7.1',
          '5.1',
          '2.1',
          '2.0',
        ],
      },
      tooltip: `Specify output container audio channels. The less audio channels produces a smaller file size.
                  \\nExample:\\n
                  7.1
                  \\n Limited device support.
                  \\nExample:\\n
                  5.1
                  \\n General home theatre surround sound.
                  \\nExample:\\n
                  2.1
                  \\n Stereo audio with bass speaker.
                  \\nExample:\\n
                  2.0
                  \\n Basic stereo sound.`,
    },
    {
      name: 'target_audio_channel_bitrate',
      type: 'number',
      defaultValue: '48',
      inputUI: {
        type: 'dropdown',
        options: [
          '48',
          '64',
          '96',
          '128',
          '192',
        ],
      },
      tooltip: `Select output audio bitrate (kbps) per audio channel. This value should not be confused with total audio bitrate - its value is per audio channel only.
                  \\nExample:\\n
                  48 - 2.0 stereo 96k, 2.1 stereo at 144k, Surround 5.1 at 288k, surround 7.1 at 384k
                  \\nExample:\\n
                  64 - 2.0 stereo 128k, 2.1 stereo at 192k, Surround 5.1 at 384k, surround 7.1 at 512k
                  \\nExample:\\n
                  96 - 2.0 stereo 192k, 2.1 stereo at 288k, Surround 5.1 at 576k, surround 7.1 at 768k
                  \\nExample:\\n
                  128 - 2.0 stereo 256k, 2.1 stereo at 384k, Surround 5.1 at 768k, surround 7.1 at 1024k
                  \\nExample:\\n
                  192 - 2.0 stereo 384k, 2.1 stereo at 576k, Surround 5.1 at 1152k, surround 7.1 at 1536k`,
    },
  {
    name: 'audio_codec',
    type: 'string',
    defaultValue: 'aac',
    inputUI: {
      type: 'dropdown',
      options: [
        'aac',
        'ac3',
      ],
    },
    tooltip: `Specify the output audio codec. Use "aac" for maximum compatibility with devices.`,
  },
  ],
});

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const plugin = (file, librarySettings, inputs, otherArguments) => {
  const lib = require('../methods/lib')();
  const os = require('os');
  const proc = require('child_process');
  // eslint-disable-next-line @typescript-eslint/no-unused-vars,no-param-reassign
  inputs = lib.loadDefaultValues(inputs, details);
  const response = {
    processFile: false,
    container: `.${file.container}`,
    handBrakeMode: false,
    FFmpegMode: true,
    reQueueAfter: true,
    infoLog: '',
  };


  // Check if file is a video. If it isn't then exit plugin.
  if (file.fileMedium !== 'video') {
    // eslint-disable-next-line no-console
    console.log('File is not video');
    response.infoLog += '☒File is not video. \n';
    response.processFile = false;
    return response;
  }

  // Function to update 'isXchannelAdded' value
  function updateIsChannelAdded(audioChannels) {
    switch (audioChannels) {
      case 2:
        is2channelAdded = true;
        break;
      case 3:
        is3channelAdded = true;
        break;
      case 6:
        is6channelAdded = true;
        break;
      case 8:
        is8channelAdded = true;
        break;
      // Add more cases as needed
      default:
        break;
    }
  }

  // Set up required variables.
  let ffmpegCommandInsert = '';
  let audioIdx = 0;
  let audioChannels = '';
  let audioBitrate = '';
  let audioChannelsTitle = '';
  let bitratePercentageThreshold = 10;  // Bitrate % threshold
  let has2Channel = false;
  let has3Channel = false;
  let has6Channel = false;
  let has8Channel = false;
  let maxChannelCount = 0;
  let convert = false;
  let is2channelAdded = false;
  let is3channelAdded = false;
  let is6channelAdded = false;
  let is8channelAdded = false;
  const audioBitrateChannelMin = 48;  // Minimum bitrate per audio channel


  // Set FFmpeg audio channels vars
  if (inputs.target_audio_channels === '7.1') {
    audioChannels = 8;
    audioChannelsTitle = '7.1';
    audioBitrate = (audioChannels * inputs.target_audio_channel_bitrate);
    if (audioBitrate <= (audioBitrateChannelMin * audioChannels)) {
      audioBitrate = (audioBitrateChannelMin * audioChannels);  // Override if user bitrate preset too low
    }
  } else if (inputs.target_audio_channels === '5.1') {
    audioChannels = 6;
    audioChannelsTitle = '5.1';
    audioBitrate = (audioChannels * inputs.target_audio_channel_bitrate);
    if (audioBitrate <= (audioBitrateChannelMin * audioChannels)) {
      audioBitrate = (audioBitrateChannelMin * audioChannels);  // Override if user bitrate preset too low
    }
  } else if (inputs.target_audio_channels === '2.1') {
    audioChannels = 3;
    audioChannelsTitle = '2.1';
    audioBitrate = (audioChannels * inputs.target_audio_channel_bitrate);
    if (audioBitrate <= (audioBitrateChannelMin * audioChannels)) {
      audioBitrate = (audioBitrateChannelMin * audioChannels);  // Override if user bitrate preset too low
    }
  } else if (inputs.target_audio_channels === '2.0') {
    audioChannels = 2;
    audioChannelsTitle = '2.0';
    audioBitrate = (audioChannels * inputs.target_audio_channel_bitrate);
    if (audioBitrate <= (audioBitrateChannelMin * audioChannels)) {
      audioBitrate = (audioBitrateChannelMin * audioChannels);  // Override if user bitrate preset too low
    }
  }


  // Go through each stream in the file.
  for (let i = 0; i < file.ffProbeData.streams.length; i++) {
    try {
      // Go through all audio streams and check if 2,3,6 & 8 channel tracks exist or not.
      if (file.ffProbeData.streams[i].codec_type.toLowerCase() === 'audio') {
        const currentChannelCount = file.ffProbeData.streams[i].channels;

        // Update maxChannelCount if the current channel count is greater
        if (currentChannelCount > maxChannelCount) {
          maxChannelCount = currentChannelCount;
        }

        // Check for specific channel counts if needed (2, 3, 6, 8)
        if (file.ffProbeData.streams[i].channels === 2) {
          has2Channel = true;
        }
        if (file.ffProbeData.streams[i].channels === 3) {
          has3Channel = true;
        }
        if (file.ffProbeData.streams[i].channels === 6) {
          has6Channel = true;
        }
        if (file.ffProbeData.streams[i].channels === 8) {
          has8Channel = true;
        }
      }
    } catch (err) {
      // Error
    }
  }

  // Reduce audio channels down a level if required (source file cannot support user setting)
  if (audioChannels > maxChannelCount) {
    audioChannels =  maxChannelCount;  // Down sample the audio channels to max available
    if (audioChannels === 8) {
      audioChannelsTitle = '7.1';
      audioBitrate = (audioChannels * inputs.target_audio_channel_bitrate);
    } else if (audioChannels === 6) {
      audioChannelsTitle = '5.1';
      audioBitrate = (audioChannels * inputs.target_audio_channel_bitrate);
    } else if (audioChannels === 3) {
      audioChannelsTitle = '2.1';
      audioBitrate = (audioChannels * inputs.target_audio_channel_bitrate);
    } else if (audioChannels === 2) {
      audioChannelsTitle = '2.0';
      audioBitrate = (audioChannels * inputs.target_audio_channel_bitrate);
    }
    // Check audio bitrate
    if (audioBitrate <= (audioBitrateChannelMin * audioChannels)) {
      audioBitrate = (audioBitrateChannelMin * audioChannels);  // Override if user bitrate preset too low
    }
  }

  // Go through each stream in the file.
  for (let i = 0; i < file.ffProbeData.streams.length; i++) {
    // Check if stream is audio.
    if (file.ffProbeData.streams[i].codec_type.toLowerCase() === 'audio') {
      try {

        // Reset variables at the beginning of each iteration
        let audioFileCodec;
        let audioFileBitrate;
        let upperLimit;
        let lowerLimit;

        // Audio input file codec
        audioFileCodec = file.ffProbeData.streams[i].codec_name.toLowerCase()

        // Audio input file bitrate
        const bitrateProbe = parseFloat(file.ffProbeData.streams[i].bit_rate);
        if (!isNaN(bitrateProbe)) {
          audioFileBitrate = ((file.ffProbeData.streams[i].bit_rate / 1000) / file.ffProbeData.streams[i].channels)

          // Calculate audio upper and lower bitrate allowed threshold limits
          upperLimit = ((file.ffProbeData.streams[i].bit_rate / 1000) / file.ffProbeData.streams[i].channels) * (1 + bitratePercentageThreshold / 100);
          lowerLimit = ((file.ffProbeData.streams[i].bit_rate / 1000) / file.ffProbeData.streams[i].channels) * (1 - bitratePercentageThreshold / 100);
        } else {
          response.processFile = false;
          return response;          
        }

        // Check if encoding is required or not
        if (
          audioFileCodec === inputs.audio_codec &&
          audioChannels === file.ffProbeData.streams[i].channels &&
          audioFileCodec === inputs.audio_codec &&
          audioFileBitrate === audioBitrate
        ) {
          response.processFile = false;
          return response;
        }

        // Check if file has 8 channel audio, no 6 or 3 or 2 channel, require X channel, if so create X.
        if (
            has8Channel === true &&
          (
            (audioChannels === 8 && is8channelAdded === false) ||
            (audioChannels === 6 && has6Channel === false && is6channelAdded === false) ||
            (audioChannels === 3 && has3Channel === false && is3channelAdded === false) ||
            (audioChannels === 2 && has2Channel === false && is2channelAdded === false)
          )
        ) {
            if (
              audioChannels === 8 &&
              audioFileCodec === inputs.audio_codec &&
              (!isNaN(audioFileBitrate) && audioFileBitrate >= lowerLimit && audioFileBitrate <= upperLimit)
            ) {
              // Copy audio stream
              ffmpegCommandInsert += ` -map 0:a:${i} -metadata:s:a:${audioIdx} title="${audioChannelsTitle}" `;
              convert = true;  // Set to encode
              updateIsChannelAdded(audioChannels);
            } else {
              // Encode audio stream
              ffmpegCommandInsert += `-map 0:${i} -c:a:${audioIdx} ${inputs.audio_codec} -b:a ${audioBitrate}k -ac ${audioChannels} -metadata:s:a:${audioIdx} title="${audioChannelsTitle}" `;
              convert = true;  // Set to encode
              updateIsChannelAdded(audioChannels);
          }
        }

        // Check if file has 6 channel audio, no 3 or 2 channel, require X channel, if so create X.
        if (
            has6Channel === true &&
          (
            (audioChannels === 6 && is6channelAdded === false) ||
            (audioChannels === 3 && has3Channel === false && is3channelAdded === false) ||
            (audioChannels === 2 && has2Channel === false && is2channelAdded === false)
          )
        ) {
            if (
              audioChannels === 6 &&
              audioFileCodec === inputs.audio_codec &&
              (!isNaN(audioFileBitrate) && audioFileBitrate >= lowerLimit && audioFileBitrate <= upperLimit)
            ) {
              // Copy audio stream
              ffmpegCommandInsert += ` -map 0:a:${i} -metadata:s:a:${audioIdx} title="${audioChannelsTitle}" `;
              convert = true;  // Set to encode
              updateIsChannelAdded(audioChannels);
            } else {
              // Encode audio stream
              ffmpegCommandInsert += `-map 0:${i} -c:a:${audioIdx} ${inputs.audio_codec} -b:a ${audioBitrate}k -ac ${audioChannels} -metadata:s:a:${audioIdx} title="${audioChannelsTitle}" `;
              convert = true;  // Set to encode
              updateIsChannelAdded(audioChannels);
          }
        }

        // Check if file has 3 channel audio, no 2 channel, require X channel, if so create X.
        if (
            has3Channel === true &&
          (
            (audioChannels === 3 && is3channelAdded === false) ||
            (audioChannels === 2 && has2Channel === false && is2channelAdded === false)
          )
        ) {
            if (
              audioChannels === 3 &&
              audioFileCodec === inputs.audio_codec &&
              (!isNaN(audioFileBitrate) && audioFileBitrate >= lowerLimit && audioFileBitrate <= upperLimit)
            ) {
              // Copy audio stream
              ffmpegCommandInsert += ` -map 0:a:${i} -metadata:s:a:${audioIdx} title="${audioChannelsTitle}" `;
              convert = true;  // Set to encode
              updateIsChannelAdded(audioChannels);
            } else {
              // Encode audio stream
              ffmpegCommandInsert += `-map 0:${i} -c:a:${audioIdx} ${inputs.audio_codec} -b:a ${audioBitrate}k -ac ${audioChannels} -metadata:s:a:${audioIdx} title="${audioChannelsTitle}" `;
              convert = true;  // Set to encode
              updateIsChannelAdded(audioChannels);
          }
        }

        // Check if file has 2 channel audio, require 2.0, if so create 2.0.
        if (
          has2Channel === true &&
          audioChannels === 2 &&
          is2channelAdded === false
        ) {
            if (
              audioFileCodec === inputs.audio_codec &&
              (!isNaN(audioFileBitrate) && audioFileBitrate >= lowerLimit && audioFileBitrate <= upperLimit)
            ) {
              // Copy audio stream
              ffmpegCommandInsert += ` -map 0:a:${i} -metadata:s:a:${audioIdx} title="${audioChannelsTitle}" `;
              convert = true;  // Set to encode
              updateIsChannelAdded(audioChannels);
            } else {
              // Encode audio stream
              ffmpegCommandInsert += `-map 0:${i} -c:a:${audioIdx} ${inputs.audio_codec} -b:a ${audioBitrate}k -ac ${audioChannels} -metadata:s:a:${audioIdx} title="${audioChannelsTitle}" `;
              convert = true;  // Set to encode
              updateIsChannelAdded(audioChannels);
          }
        }

      } catch (err) {
        // Error
      }
      audioIdx += 1;
    }
  }

  // Convert file if convert variable is set to true.
  if (convert === true) {
    response.processFile = true;
    response.preset = `, -map 0 -c:v copy -c:s copy ${ffmpegCommandInsert} `
    + '-strict -2 -c:s copy -max_muxing_queue_size 9999 ';
    response.infoLog += `Audio track channel bitrate is not within 10% of ${audioBitrate} kbps \n`;
    response.infoLog += `☑Encoding ${audioChannels} channel audio track at ${audioBitrate} kbps per channel \n`;
  } else {
    response.infoLog += '☑File contains required audio formats and channel bitrate. \n';
  }
  return response;
};
module.exports.details = details;
module.exports.plugin = plugin;

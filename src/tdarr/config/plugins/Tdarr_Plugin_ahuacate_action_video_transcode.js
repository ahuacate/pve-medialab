// Notes: V1.0 requires FFmpeg 6.1. "-cq:v" fails for unknown reason. Patched with "-qp:v".

/* eslint no-plusplus: ["error", { "allowForLoopAfterthoughts": true }] */
const details = () => ({
  id: 'Tdarr_Plugin_ahuacate_action_video_transcode',
  Stage: 'Pre-processing',
  Name: 'Ahua-Transcode a video file',
  Type: 'Video',
  Operation: 'Transcode',
  Description: `Transcode a video exclusively using ffmpeg, utilizing Va-api iGPU transcoding when available.
  The preset defaults are optimized for streaming video transcodes, employing the HEVC codec. Video remux when source is within bitrate range.`,
  Version: '1.0',
  Tags: 'pre-processing,ffmpeg,video only,nvenc h265,remux,configurable',
  Inputs: [
    {
      name: 'target_codec',
      type: 'string',
      defaultValue: 'hevc',
      inputUI: {
        type: 'dropdown',
        options: [
          'hevc',
          // 'vp9',
          'h264',
          // 'vp8',
        ],
      },
      tooltip: `Specify the codec to use. For HDR video you MUST select hevc.
                  \\nExample:\\n
                  hevc - latest High Efficiency Video Coding. HEVC will create a file about 50% smaller than h264. Required for hdr 10bit. (recommended default)
                  \\nExample:\\n
                  h264 - older generation, most common video compression standard`,
    },
    {
      name: 'enable_QP_CQ_Control',
      type: 'boolean',
      defaultValue: false,
      inputUI: {
        type: 'dropdown',
        options: [
          'false',
          'true',
        ],
      },
      tooltip: `Enable or disable "cq" (constant quantization) and "qp" (quantization parameter) control parameters.
                  \\n CQ and QP are used in video encoding to manage the quality of the encoded video.
                  \\n This plugin uses either depending on the encoder used.
                  \\n Enable this option for higher quality video transcodes (archiving, main video library).
                  \\n Disable for small video transcodes (streaming video library).
                  \\n Select your quality parameter value in "Target_Q_Value" option.`
    },
    {
      name: 'Target_Q_Value',
      type: 'number',
      defaultValue: 23,
      inputUI: {
        type: 'dropdown',
        options: [
          '19',
          '23',
          '28',
          '33',
          '38',
        ],
      },
      tooltip: `In FFmpeg, "cq" (constant quantization) and "qp" (quantization parameter) are control parameters
                  \\n used in video encoding to manage the quality of the encoded video.
                  \\n This plugin uses either depending on the encoder used.
                  \\n This plugin requires "enable_QP_CQ_Control' to be enabled.
                  \\n The bitrate in CQ and QP modes are not fixed; it varies based on the complexity of the video.
                  \\n In CQ mode, the encoder will allocate more bits to complex scenes and fewer bits to
                  \\n less complex scenes.
                  \\n In QP mode, the parameter defines how much information to discard from a given block
                  \\n of pixels (a Macroblock). This leads to a hugely varying bitrate over the entire sequence.
                  \\n This results in a variable bitrate while maintaining a constant quality.
                  \\n QP is disabled when the input video is too small and may contain artifacts resulting in
                  \\n unnecessary large output video files.
                      \\nExample:\\n
                      19 - High Quality, Large File Size
                      \\nExample:\\n
                      23 - Good Quality, Moderate File Size (default)
                      \\nExample:\\n
                      28 - Acceptable Quality, Smaller File Size
                      \\nExample:\\n
                      33 - Lower Quality, Small File Size
                      \\nExample:\\n
                      38 - Minimal Quality, Very Small File Size`,
    },
    {
      name: 'enable_Hdr',
      type: 'boolean',
      defaultValue: true,
      inputUI: {
        type: 'dropdown',
        options: [
          'false',
          'true',
        ],
      },
      tooltip: `HDR video can be scaled, reprocessed or remuxed retaining HDR format in 10bit hevc.
                  \\n Disabling this setting does not perform HDR to SDR tone mapping or conversion.
                  \\n Disabling skips all hdr source files.`,
    },
    {
      name: 'Max_Video_Height',
      type: 'string',
      defaultValue: 1080,
      inputUI: {
        type: 'dropdown',
        options: [
          '720',
          '1080',
          '2160',
          '4320',
          'original',
        ],
      },
      tooltip: `Set your output video size. All videos over the set size will be rescaled. We recommend 1080 for streaming.
                  \\nExample:\\n
                  720 - for HD video
                  \\nExample:\\n
                  1080 - for 2K video (default)
                  \\nExample:\\n
                  2160 - for 4K video
                  \\nExample:\\n
                  original - for matching the input video size`,
    },
    {
      name: 'target_bitrate_multiplier',
      type: 'number',
      defaultValue: 0.35,
      inputUI: {
        type: 'text',
      },
      tooltip: `Define the bitrate multiplier to determine the target bitrate.
                  \\n This multiplier is applied to the input video bitrate, accounting for any adjustments due to video resizing.
                      \\nExample:\\n
                      0.5 - Logic of hevc/h265 can be half the bitrate as h264 without losing quality
                      \\nExample:\\n
                      0.35 - Our stream setting (default)
                      \\nExample:\\n
                      0.25 - This will produce a video about quarter of the original size`,
    },
    {
      name: 'target_bitrate_throttle',
      type: 'number',
      defaultValue: '50',
      inputUI: {
        type: 'text',
      },
      tooltip: `Bitrate throttling sets a bitrate limit for the encoder. Specify the average bitrate in Mbps for high frame rate 4K video (e.g., 48, 50, 60fps). The plugin will calculate bitrate and frame rates for other video resolutions based on this input.
                  \\n Input numeric value only.
                  \\n Set to '0' to disable bitrate throttling.
                  \\n Recommended 4K video bitrate for hevc (h.264 will be 2x or double our recommendation):'
                      \\nExample:\\n
                      50 - Average 4K Youtube or NetFlix bitrate for high frame rate video
                      \\n A input of 50 Mbps (recommended) will set your encoder limits to:
                      \\n High Frame Rate content:
                      \\n    4k at 50Mbps : 1080p at 12 Mbps : 720p at 7.5 Mbps
                      \\n Recalculated Low Frame Rate content:
                      \\n    4k at 35Mbps : 1080p at 8 Mbps : 720p at 5 Mbps`,
    },
    {
      name: 'try_use_gpu',
      type: 'boolean',
      defaultValue: true,
      inputUI: {
        type: 'dropdown',
        options: [
          'false',
          'true',
        ],
      },
      tooltip: 'If enabled then will use GPU if possible.',
    },
    {
      name: 'container',
      type: 'string',
      defaultValue: 'mkv',
      inputUI: {
        type: 'dropdown',
        options: [
          'mkv',
          'mp4',
          'avi',
          'ts',
          'original',
        ],
      },
      tooltip: `Specify output container of file.
                  \\nExample:\\n
                  mkv
                  \\n Matroska is a universal container, supports hevc hdr10 and subtitle tracks in one file. Recommended (default).
                  \\nExample:\\n
                  mp4
                  \\n Better compatibility and widely supported. BUT issues when input files contain subtitle streams. If you choose mp4 you must have a remove all subtitles plugin in your process stack before transcoding or enable 'force_conform'.
                  \\nExample:\\n
                  avi
                  \\nExample:\\n
                  ts
                  \\nExample:\\n
                  original
                  \\n Not recommended unless you know the source file containers formats.`,
    },
    {
      name: 'bitrate_cutoff',
      type: 'number',
      defaultValue: 3000,
      inputUI: {
        type: 'text',
      },
      tooltip: `Specify bitrate cutoff, input files with a video bitrate lower than this setting
                  \\n will not be transcoded. A remux will be performed if possible.
                  \\n Rate is in kbps.
                  \\n Leave empty (0) to disable.
                      \\nExample:\\n
                      3000 (default)
                      \\nExample:\\n
                      4000`,
    },
    {
      name: 'enable_10bit',
      type: 'boolean',
      defaultValue: true,
      inputUI: {
        type: 'dropdown',
        options: [
          'false',
          'true',
        ],
      },
      tooltip: `Specify if output file should be 10bit. Enable for hevc including non-hdr files to create superior quality small files.
                      \\nExample:\\n
                      true - (default)
                      \\nExample:\\n
                      false`,
    },
    {
      name: 'bframes_enabled',
      type: 'boolean',
      defaultValue: false,
      inputUI: {
        type: 'dropdown',
        options: [
          'false',
          'true',
        ],
      },
      tooltip: `Specify if b frames should be used.
                  \\n Using B frames should decrease file sizes but are only supported on newer GPUs. Enable if your iGPU supports this function.
                    \\nExample:\\n
                    true
                    \\nExample:\\n
                    false`,
    },
    {
      name: 'bframes_value',
      type: 'number',
      defaultValue: 5,
      inputUI: {
        type: 'text',
      },
      tooltip: 'Specify number of bframes to use. The typical range for the number of B-frames is 0 to 16, but the optimal value can vary based on the content of the video, the encoding settings, and the target playback environment. Our recommended value is 5.',
    },
    {
      name: 'force_conform',
      type: 'boolean',
      defaultValue: false,
      inputUI: {
        type: 'dropdown',
        options: [
          'false',
          'true',
        ],
      },
      tooltip: `Make the file conform to output containers requirements. You may consider enabling this setting if you choose to use mp4 containers.
                  \\n Drop hdmv_pgs_subtitle/eia_608/subrip/timed_id3 for MP4.
                  \\n Drop data streams/mov_text/eia_608/timed_id3 for MKV.
                  \\n Default is false.
                      \\nExample:\\n
                      true
                      \\nExample:\\n
                      false`,
    },
    {
      name: 'exclude_gpus',
      type: 'string',
      defaultValue: '',
      inputUI: {
        type: 'text',
      },
      tooltip: `Specify the id(s) of any GPUs that needs to be excluded from assigning transcoding tasks.
                  \\n Separate with a comma (,). Leave empty to disable.
                  \\n Get GPU numbers in the node by running 'nvidia-smi'
                      \\nExample:\\n
                      0,1,3,8
                      \\nExample:\\n
                      3
                      \\nExample:\\n
                      0`,
    },
  ],
});

const bframeSupport = [
  'hevc_nvenc',
  'h264_nvenc',
];

const hasEncoder = async ({
  ffmpegPath,
  encoder,
  inputArgs,
  filter,
}) => {
  const { exec } = require('child_process');
  let isEnabled = false;
  try {
    isEnabled = await new Promise((resolve) => {
      const command = `${ffmpegPath} ${inputArgs || ''} -f lavfi -i color=c=black:s=256x256:d=1:r=30`
              + ` ${filter || ''}`
              + ` -c:v ${encoder} -f null /dev/null`;
      exec(command, (
        error,
        // stdout,
        // stderr,
      ) => {
        if (error) {
          resolve(false);
          return;
        }
        resolve(true);
      });
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.log(err);
  }

  return isEnabled;
};

// credit to UNCode101 for this
const getBestNvencDevice = ({
  response,
  inputs,
  nvencDevice,
}) => {
  const { execSync } = require('child_process');
  let gpu_num = -1;
  let lowest_gpu_util = 100000;
  let result_util = 0;
  let gpu_count = -1;
  let gpu_names = '';
  const gpus_to_exclude = inputs.exclude_gpus === '' ? [] : inputs.exclude_gpus.split(',').map(Number);
  try {
    gpu_names = execSync('nvidia-smi --query-gpu=name --format=csv,noheader');
    gpu_names = gpu_names.toString().trim();
    gpu_names = gpu_names.split(/\r?\n/);
    /* When nvidia-smi returns an error it contains 'nvidia-smi' in the error
      Example: Linux: nvidia-smi: command not found
               Windows: 'nvidia-smi' is not recognized as an internal or external command,
                   operable program or batch file. */
    if (!gpu_names[0].includes('nvidia-smi')) {
      gpu_count = gpu_names.length;
    }
  } catch (error) {
    response.infoLog += 'Error in reading nvidia-smi output! \n';
    // response.infoLog += error.message;
  }

  if (gpu_count > 0) {
    for (let gpui = 0; gpui < gpu_count; gpui++) {
      // Check if GPU # is in GPUs to exclude
      if (gpus_to_exclude.includes(gpui)) {
        response.infoLog += `GPU ${gpui}: ${gpu_names[gpui]} is in exclusion list, will not be used!\n`;
      } else {
        try {
          const cmd_gpu = `nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i ${gpui}`;
          result_util = parseInt(execSync(cmd_gpu), 10);
          if (!Number.isNaN(result_util)) { // != "No devices were found") {
            response.infoLog += `GPU ${gpui} : Utilization ${result_util}%\n`;

            if (result_util < lowest_gpu_util) {
              gpu_num = gpui;
              lowest_gpu_util = result_util;
            }
          }
        } catch (error) {
          response.infoLog += `Error in reading GPU ${gpui} Utilization\nError: ${error}\n`;
        }
      }
    }
  }
  if (gpu_num >= 0) {
    // eslint-disable-next-line no-param-reassign
    nvencDevice.inputArgs = `-hwaccel_device ${gpu_num}`;
    // eslint-disable-next-line no-param-reassign
    nvencDevice.outputArgs = `-gpu ${gpu_num}`;
  }

  return nvencDevice;
};

const getEncoder = async ({
  response,
  inputs,
  otherArguments,
}) => {
  if (
    otherArguments.workerType
    && otherArguments.workerType.includes('gpu')
    && inputs.try_use_gpu && (inputs.target_codec === 'hevc' || inputs.target_codec === 'h264')) {
    const gpuEncoders = [
      {
        encoder: 'hevc_nvenc',
        enabled: false,
      },
      {
        encoder: 'hevc_amf',
        enabled: false,
      },
      {
        encoder: 'hevc_vaapi',
        inputArgs: '-hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi',
        enabled: false,
        filter: '-vf format=nv12,hwupload',
      },
      {
        encoder: 'hevc_qsv',
        enabled: false,
      },
      {
        encoder: 'hevc_videotoolbox',
        enabled: false,
      },

      {
        encoder: 'h264_nvenc',
        enabled: false,
      },
      {
        encoder: 'h264_amf',
        enabled: false,
      },
      {
        encoder: 'h264_qsv',
        enabled: false,
      },
      {
        encoder: 'h264_videotoolbox',
        enabled: false,
      },
    ];

    const filteredGpuEncoders = gpuEncoders.filter((device) => device.encoder.includes(inputs.target_codec));

    // eslint-disable-next-line no-restricted-syntax
    for (const gpuEncoder of filteredGpuEncoders) {
      // eslint-disable-next-line no-await-in-loop
      gpuEncoder.enabled = await hasEncoder({
        ffmpegPath: otherArguments.ffmpegPath,
        encoder: gpuEncoder.encoder,
        inputArgs: gpuEncoder.inputArgs,
        filter: gpuEncoder.filter,
      });
    }

    const enabledDevices = gpuEncoders.filter((device) => device.enabled === true);

    if (enabledDevices.length > 0) {
      if (enabledDevices[0].encoder.includes('nvenc')) {
        return getBestNvencDevice({
          response,
          inputs,
          nvencDevice: enabledDevices[0],
        });
      }
      return enabledDevices[0];
    }
  }

  if (inputs.target_codec === 'hevc') {
    return {
      // Your hevc-specific logic
      encoder: 'libx265',
      inputArgs: '',
    };
  } if (inputs.target_codec === 'h264') {
    return {
      // Your h264-specific logic
      encoder: 'libx264',
      inputArgs: '',
    };
  }

  return {
    encoder: '',
    inputArgs: '',
  };
};

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const plugin = async (file, librarySettings, inputs, otherArguments) => {
  const lib = require('../methods/lib')();
  // eslint-disable-next-line @typescript-eslint/no-unused-vars,no-param-reassign
  inputs = lib.loadDefaultValues(inputs, details);
  const response = {
    processFile: false,
    preset: '',
    handBrakeMode: false,
    FFmpegMode: true,
    reQueueAfter: true,
    infoLog: '',
    metaData: '',
  };

  const encoderProperties = await getEncoder({
    response,
    inputs,
    otherArguments,
  });

  // Convert to a number if it's a numeric string
  inputs.Max_Video_Height = /^\d+$/.test(inputs.Max_Video_Height)
    ? parseInt(inputs.Max_Video_Height, 10)
    : inputs.Max_Video_Height;

  // Set file container
  if (inputs.container === 'original') {
    response.container = `.${file.container}`;
  } else {
    response.container = `.${inputs.container}`;
  }

  // Check if file is a video. If it isn't then exit plugin.
  if (file.fileMedium !== 'video') {
    response.infoLog += '☑File is not a video. \n';
    return response;
  }

  let duration = 0;

  // Get duration in seconds
  if (parseFloat(file.ffProbeData?.format?.duration) > 0) {
    duration = parseFloat(file.ffProbeData?.format?.duration);
  } else if (typeof file.meta.Duration !== 'undefined') {
    duration = file.meta.Duration;
  } else {
    duration = file.ffProbeData.streams[0].duration;
  }

  // Set up required variables.
  let videoIdx = 0;
  let CPU10 = false;
  let streamHdr = false;
  let stream10bit = false;
  let extraArguments = '';
  let genpts = '';
  let bitrateSettings = '';
  let videoHeight = file.ffProbeData.streams[videoIdx].height * 1;
  let videoWidth = file.ffProbeData.streams[videoIdx].width * 1;
  let videoFrameRateFraction = file.ffProbeData.streams[videoIdx].r_frame_rate;
  let [numerator, denominator] = videoFrameRateFraction.split('/').map(Number);
  let videoFrameRate = numerator / denominator;
  let videoFrameRateFactor = 0.875;  // factor to convert high frame rate to low standard frame rate
  let bitrateThrottle = '';
  let targetBitrate ='';
  let bolScaleVideo = false;
  let videoResizeFactor = 1;  // Initialize to 1
  let videoFilters = '';
  let otherTags = '';
  let quantizationType = '';
  let outputDir = librarySettings.output; // gets output/destination dir
  let inputDir = librarySettings.input; // gets input dir


  // Calculate bitrate throttle (cutoff fps is 35)
  if (inputs.target_bitrate_throttle) {
    if (inputs.Max_Video_Height === 720) {
      if (videoFrameRate < 35) {
        bitrateThrottle = Math.floor((((1280 * 720) / (3840 * 2160)) * inputs.target_bitrate_throttle * 1000000) * videoFrameRateFactor);
      } else {
        bitrateThrottle = Math.floor(((1280 * 720) / (3840 * 2160)) * inputs.target_bitrate_throttle * 1000000);
      }
    } else if (inputs.Max_Video_Height === 1080) {
      if (videoFrameRate > 35) {
        bitrateThrottle = Math.floor(((1920 * 1080) / (3840 * 2160)) * inputs.target_bitrate_throttle * 1000000);
      } else {
        bitrateThrottle = Math.floor((((1920 * 1080) / (3840 * 2160)) * inputs.target_bitrate_throttle * 1000000) * videoFrameRateFactor);
      }
    } else if (inputs.Max_Video_Height === 2160) {
      if (videoFrameRate > 35) {
        bitrateThrottle = Math.floor(inputs.target_bitrate_throttle * 1000000);
      } else {
        bitrateThrottle = Math.floor((inputs.target_bitrate_throttle * 1000000) * videoFrameRateFactor);
      }
    } else if (inputs.Max_Video_Height === 4320) {
      if (videoFrameRate > 35) {
        bitrateThrottle = Math.floor(((7680 * 4320) / (3840 * 2160)) * inputs.target_bitrate_throttle * 1000000);
      } else {
        bitrateThrottle = Math.floor((((7680 * 4320) / (3840 * 2160)) * inputs.target_bitrate_throttle * 1000000) * videoFrameRateFactor);
      }
    } else if (inputs.Max_Video_Height === 'original') {
      if (videoFrameRate > 35) {
        bitrateThrottle = Math.floor(((videoWidth * videoHeight) / (3840 * 2160)) * inputs.target_bitrate_throttle * 1000000);
      } else {
        bitrateThrottle = Math.floor((((videoWidth * videoHeight) / (3840 * 2160)) * inputs.target_bitrate_throttle * 1000000) * videoFrameRateFactor);
      }
    }
  }

  // Used from here https://blog.frame.io/2017/03/06/calculate-video-bitrates/

  // Check if we need to scale down the video size
  if ((inputs.Max_Video_Height !== 'original') && (videoHeight > inputs.Max_Video_Height)) {
    bolScaleVideo = true;
    videoNewWidth = Math.floor((inputs.Max_Video_Height / videoHeight) * videoWidth);
    response.infoLog
      += `☑Video Resolution, ${videoWidth}x${videoHeight}, need to convert to ${videoNewWidth}x${inputs.Max_Video_Height} \n`;
    videoResizeFactor = (inputs.Max_Video_Height / videoHeight);  // Apply video resize factor
    videoHeight = inputs.Max_Video_Height;
    videoWidth = videoNewWidth;
  } else if (inputs.Max_Video_Height === 'original') {
    videoResizeFactor = 1;  // Apply no resize factor
    response.infoLog += `☑Video Resolution: ${videoWidth}x${videoHeight} (resize factor:1) \n`;
  }

  // The formula essentially multiplies the file size in bytes by 8 (to convert to bits)
  // and then divides this by the duration of the video in seconds.
  // The result is the average bitrate of the video in bits per second (bps).
  // For non hevc source videos a multiplier factor of x2 is applied.
  if (file.ffProbeData.streams[videoIdx].codec_name === 'hevc') {
    currentBitrate = Math.round(((file.file_size * 1024 * 1024 * 8) / duration) * 2);
    response.infoLog += `☑Input file bitrate: ${currentBitrate} (hevc) \n`;
  } else {
    currentBitrate = Math.round((file.file_size * 1024 * 1024 * 8) / duration);
    response.infoLog += `☑Input file bitrate: ${currentBitrate} (non-hevc) \n`;
  }

  // Check 'targetBitrate' doesn't exceed 'bitrateThrottle'
  if (Math.round(currentBitrate * videoResizeFactor) > bitrateThrottle) {
    // Override and set to apply 'bitrateThrottle'
    if (inputs.target_codec === 'hevc') {
      targetBitrate = Math.round(bitrateThrottle * inputs.target_bitrate_multiplier);
    } else if (inputs.target_codec === 'h264') {
      targetBitrate = bitrateThrottle;
    }
    response.infoLog += `☑Bitrate throttle: enabled \n`;
    response.infoLog += `☑Output file throttle bitrate: ${bitrateThrottle} \n`;
    response.infoLog += `☑Video frame rate: ${videoFrameRate}fps \n`;
  } else {
    if (inputs.target_codec === 'hevc') {
      targetBitrate = Math.round((currentBitrate * videoResizeFactor) * inputs.target_bitrate_multiplier);
    } else if (inputs.target_codec === 'h264') {
      targetBitrate = Math.round(currentBitrate * videoResizeFactor);
    }
    response.infoLog += `☑Bitrate throttle: disabled \n`;
    response.infoLog += `☑Video frame rate: ${videoFrameRate}fps \n`;
  }

  // Check if source file bitrate is too slow to support QP or CP quantization
  // With low quality source video (artifacts), ffmpeg -qp may create a file size
  // greater than source file.
  // So solution is to disable -qp option and use target, min, max bitrate only.
  if (inputs.enable_QP_CQ_Control) {
    if (2 * targetBitrate > currentBitrate) {
      inputs.enable_QP_CQ_Control = false;
    }
  }

  // Allow some leeway under and over the targetBitrate.
  const minimumBitrate = Math.round(targetBitrate * 0.7);
  const maximumBitrate = Math.round(targetBitrate * 1.3);

  // If Container .ts or .avi set genpts to fix unknown timestamp
  if (inputs.container === 'ts' || inputs.container === 'avi') {
    genpts = '-fflags +genpts';
  }

  // If targetBitrate comes out as 0 then something has gone wrong and bitrates could not be calculated.
  // Cancel plugin completely.
  if (targetBitrate === 0) {
    response.infoLog += 'Target bitrate could not be calculated. Skipping this plugin. \n';
    return response;
  }

  // Check if inputs.bitrate cutoff is not disabled (0)
  // (Entered means user actually wants something to happen, empty would disable this).
  // Checks if currentBitrate is below inputs.bitrate_cutoff.
  // If so then cancel plugin without touching original files.
  if (inputs.bitrate_cutoff) {
    if (
      inputs.bitrate_cutoff !== 0 &&
      currentBitrate <= inputs.bitrate_cutoff * 1000 &&
      inputDir === outputDir
    ) {
      response.infoLog += `Current bitrate is below set cutoff of ${inputs.bitrate_cutoff}. Cancelling plugin. \n`;
      return response;
    }
  }

  // Check if force_conform option is checked.
  // If so then check streams and add any extra parameters required to make file conform with output format.
  if (inputs.force_conform === true) {
    if (inputs.container === 'mkv') {
      extraArguments += '-map -0:d ';
      for (let i = 0; i < file.ffProbeData.streams.length; i++) {
        try {
          if (
            file.ffProbeData.streams[i].codec_name
              .toLowerCase() === 'mov_text'
            || file.ffProbeData.streams[i].codec_name
              .toLowerCase() === 'eia_608'
            || file.ffProbeData.streams[i].codec_name
              .toLowerCase() === 'timed_id3'
          ) {
            extraArguments += `-map -0:${i} `;
          }
        } catch (err) {
          // Error
        }
      }
    }
    if (inputs.container === 'mp4') {
      for (let i = 0; i < file.ffProbeData.streams.length; i++) {
        try {
          if (
            file.ffProbeData.streams[i].codec_name
              .toLowerCase() === 'hdmv_pgs_subtitle'
            || file.ffProbeData.streams[i].codec_name
              .toLowerCase() === 'eia_608'
            || file.ffProbeData.streams[i].codec_name
              .toLowerCase() === 'subrip'
            || file.ffProbeData.streams[i].codec_name
              .toLowerCase() === 'timed_id3'
          ) {
            extraArguments += `-map -0:${i} `;
          }
        } catch (err) {
          // Error
        }
      }
    }
  }

  // Check if 10bit variable is true.
  if (inputs.enable_10bit === true) {
    // If set to true then add 10bit argument
    extraArguments += '-pix_fmt p010le ';
  }

  // Check if b frame variable is true.
  if (bframeSupport.includes(encoderProperties.encoder) && inputs.bframes_enabled === true) {
    // If set to true then add b frames argument
    extraArguments += `-bf ${inputs.bframes_value} `;
  }

  // Set Quantization type (-cq or -qp)
  // The -cq (Constant Quantization Parameter) is specific to the x264 video codec,
  // and its scale typically ranges from 0 to 51.
  // The -qp (Quantization Parameter) is used in various video codecs,
  // including H.264 and H.265 (HEVC). The -qp value typically ranges from 0 to 51.
  // The lower the value, the higher the quality and larger the file size.
  // Conversely, higher values result in lower quality and smaller file sizes.
  if (inputs.target_codec === 'hevc') {
    quantizationType = '-qp:v'
  }
  if (inputs.target_codec === 'h264') {
    quantizationType = '-qp:v'
    // quantizationType = '-cq:v'  // In FFmpeg6.1 this stopped working
  }

  // Go through each stream in the file.
  for (let i = 0; i < file.ffProbeData.streams.length; i++) {
    // Check if stream is a video.
    let codec_type = '';
    try {
      codec_type = file.ffProbeData.streams[i].codec_type.toLowerCase();
    } catch (err) {
      // err
    }

    // Video stream
    if (codec_type === 'video') {
      // Check if plugin already performed and if so skip plugin (stops loop issue)
      let comment = file.mediaInfo.track[i].Comment
      if (comment && comment.match(/ahuacate.video.transcode/i)) {
        // response.processFile = false;
        response.infoLog += `File already processed by plugin: ${details().id} \n`;
        return response;
      }

      // Check if video stream is 10bit
      if (
        inputs.target_codec === 'hevc'
        && (file.ffProbeData.streams[i].profile === 'High 10'
        || file.ffProbeData.streams[i].bits_per_raw_sample === '10')
      ) {
        stream10bit = true;
      }

      // Check if video stream is HDR
      if (
        file.ffProbeData.streams[i].color_transfer === 'smpte2084'
        && (file.ffProbeData.streams[i].color_space === 'bt2020nc' ||
          file.ffProbeData.streams[i].color_primaries === 'bt2020')
      ) {
        streamHdr = true;
        inputs.target_codec = 'hevc';  // Override setting for HDR 10bit video
        inputs.enable_10bit = true;  // Override setting for HDR 10bit video
        // if (inputs.container !== 'mkv' && inputs.container !== 'mp4') {
        //   inputs.container = 'mkv';  // Override setting for HDR 10bit video
        // }
      }

      // Check if HDR input is enabled
      if (inputs.enable_Hdr === false && streamHdr === true) {
        response.infoLog += `Processing of HDR video is disabled. Cancelling plugin. \n`;
        return response;
      }


      //// Extra Arguments ////

      // Check if codec of stream is mjpeg/png, if so then remove this "video" stream.
      // mjpeg/png are usually embedded pictures that can cause havoc with plugins.
      if (file.ffProbeData.streams[i].codec_name === 'mjpeg' || file.ffProbeData.streams[i].codec_name === 'png') {
        extraArguments += `-map -v:${videoIdx} `;
      }


      //// Add filters ////

      // Add video scale
      if (bolScaleVideo === true) {
        videoFilters += `scale_vaapi=-2:${videoHeight},`;  // Add video resize variable if required
      }

      // // Non HDR stream
      // if (streamHdr === false) {
      //   if (inputs.target_codec === 'hevc' && inputs.enable_10bit === true) {
      //     videoFilters += 'tonemap_vaapi=format=p010';  // 10bit pixel format, hevc
      //     videoFilters += ':primaries=bt709:transfer=bt2020-10:matrix=bt2020nc';
      //   } else if (inputs.target_codec === 'hevc' && inputs.enable_10bit === false) {
      //     videoFilters += 'tonemap_vaapi=format=nv12';  // 8bit pixel format, hevc
      //     videoFilters += ':matrix=bt709:primaries=bt709:transfer=bt709';
      //   } else if (inputs.target_codec === 'h264') {
      //     videoFilters += 'tonemap_vaapi=format=nv12';  // 8bit pixel format, h264
      //     videoFilters += ':matrix=bt709:primaries=bt709:transfer=bt709';
      //   }
      // }

      // Fix video filter ending
      if (videoFilters.endsWith(',')) {
        videoFilters = videoFilters.slice(0, -1);  // Remove the trailing comma if it exists
      }


      //// Add tags ////

      // Add video tags if stream is HDR10 bit
      if (streamHdr === true) {
        // Set tags for HDR content
        if (inputs.target_codec === 'hevc' && inputs.enable_10bit === true) {
          // Color transfer tag
          otherTags += file.ffProbeData.streams[i]?.color_transfer ? `-color_trc ${file.ffProbeData.streams[i].color_transfer}` : '';
          // Color primaries tag
          otherTags += file.ffProbeData.streams[i]?.color_primaries ? `-color_primaries ${file.ffProbeData.streams[i].color_primaries}` : '';
          // Color space tag
          otherTags += file.ffProbeData.streams[i]?.color_space ? `-colorspace ${file.ffProbeData.streams[i].color_space}` : '';
        }
      }

      // // Check if encoder is 'libx265' or 'libx264'
      // if (encoderProperties.encoder.includes('libx265')) {
      //   otherTags += '-rc-lookahead:v 32';  // lookahead rate control
      // }
      // if (encoderProperties.encoder.includes('libx264')) {
      //   otherTags += '-rc-lookahead:v 32';  // lookahead rate control
      // }

      
      //// Remux ////

      // Check if input & output codec are the same and if input bitrate is within
      // a range no video transcode is performed. Remux only.
      if (inputs.bitrate_cutoff) {
        if (
          inputs.target_codec === file.ffProbeData.streams[i].codec_name &&
          file.ffProbeData.streams[i].height >= 0.9 * videoHeight &&
          file.ffProbeData.streams[i].height <= 1.1 * videoHeight &&
          currentBitrate < inputs.bitrate_cutoff * 1000
        ) {
          response.infoLog += `File is in ${inputs.target_codec} and within bitrate range.\n`;
          response.infoLog += `Remux only to ${inputs.container} container.\n`;
          response.preset = `<io> -map_metadata -1 -map 0 -c copy ${extraArguments} -metadata comment=ahuacate.video.transcode`;
          response.processFile = true;
          return response;
        }
      }

      // Check if codec of stream is HDR AND check if file.container does NOT match inputs.container.
      // Remux only.
      if (
        inputs.target_codec === file.ffProbeData.streams[i].codec_name &&
        inputs.target_bitrate_multiplier === '1' &&
        bolScaleVideo === false &&
        streamHdr === true
      ) {
        response.infoLog += `File is in ${inputs.target_codec}.\n`;
        response.infoLog += `Remux only to ${inputs.container} container.\n`;
        response.preset = `<io> -map_metadata -1 -map 0 -c copy ${extraArguments} -metadata comment=ahuacate.video.transcode`;
        response.processFile = true;
        return response;
      }

      // Check if video stream is HDR or 10bit
      if (
        inputs.target_codec === 'hevc'
        && (file.ffProbeData.streams[i].profile === 'High 10'
          || file.ffProbeData.streams[i].bits_per_raw_sample === '10')
      ) {
        CPU10 = true;
      }

    }

    // Increment videoIdx.
    videoIdx += 1;
  }

  // Set bitrateSettings variable using bitrate information calculated earlier.
  bitrateSettings = `-b:v ${targetBitrate} -minrate ${minimumBitrate} `
    + `-maxrate ${maximumBitrate} -bufsize ${targetBitrate}`;
  // Print to infoLog information around file & bitrate settings.
  response.infoLog += `☑Output container type: ${inputs.container}. \n`;
  response.infoLog += `☑Input file bitrate: ${currentBitrate} \n`;
  response.infoLog += `☑Quantization parameter: ${inputs.enable_QP_CQ_Control ? 'enabled' : 'disabled'} \n`;
  response.infoLog += '☑Bitrate transcode settings: \n';
  response.infoLog += `Target = ${targetBitrate} \n`;
  response.infoLog += `Minimum = ${minimumBitrate} \n`;
  response.infoLog += `Maximum = ${maximumBitrate} \n`;
  response.infoLog += `Bufsize = ${targetBitrate} \n`;
  if (bolScaleVideo === true) {
      response.infoLog += `Video scale = ${videoWidth}:${videoHeight} \n`;
  }

  if (encoderProperties.encoder.includes('nvenc')) {
    if (file.video_codec_name === 'h263') {
      response.preset = '-c:v h263_cuvid';
    } else if (file.video_codec_name === 'h264' && CPU10 === false) {
      response.preset = '-c:v h264_cuvid';
    } else if (file.video_codec_name === 'mjpeg') {
      response.preset = '-c:v mjpeg_cuvid';
    } else if (file.video_codec_name === 'mpeg1') {
      response.preset = '-c:v mpeg1_cuvid';
    } else if (file.video_codec_name === 'mpeg2') {
      response.preset = '-c:v mpeg2_cuvid';
    } else if (file.video_codec_name === 'mpeg4') {
      response.preset = '-c:v mpeg4_cuvid';
    } else if (file.video_codec_name === 'vc1') {
      response.preset = '-c:v vc1_cuvid';
    } else if (file.video_codec_name === 'vp8') {
      response.preset = '-c:v vp8_cuvid';
    }
  }




  // const vEncode = `${quantizationType} ${inputs.Target_Q_Value} ${bitrateSettings}`;
  const vEncode = inputs.enable_QP_CQ_Control
    ? `${quantizationType} ${inputs.Target_Q_Value} ${bitrateSettings}`
    : bitrateSettings;
  const videoFiltersOption = videoFilters ? `-vf '${videoFilters}'` : '';
  const otherTagsOption = otherTags ? otherTags.split('-').filter(tag => tag).map(tag => `-${tag}`).join(' ') : '';
  const metaDataComment = `-metadata comment=ahuacate.video.transcode`;

  response.preset += ` ${encoderProperties.inputArgs ? encoderProperties.inputArgs : ''} ${genpts}<io>`
    + ` -map_metadata -1 -map 0 -c copy -c:v ${encoderProperties.encoder}`
    + ` ${encoderProperties.outputArgs ? encoderProperties.outputArgs : ''}`
    + ` ${vEncode}`
    + ` ${videoFiltersOption}`  // Add videoFilters if it has entries
    + ` ${metaDataComment}`  // Add metadata line to stop loop
    + ` ${otherTagsOption}`  // Add otherTagsOption if it has entries
    + ` -max_muxing_queue_size 9999 ${extraArguments}`;
  response.processFile = true;
  response.infoLog += `☑File is not in ${inputs.target_codec}. Transcoding. \n`;
  return response;
};
module.exports.details = details;
module.exports.plugin = plugin;
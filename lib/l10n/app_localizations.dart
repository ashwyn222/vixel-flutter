import 'package:flutter/material.dart';

enum AppLanguage {
  english,
  hindi,
}

class AppLocalizations extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.english;
  
  AppLanguage get currentLanguage => _currentLanguage;
  
  void setLanguage(AppLanguage language) {
    _currentLanguage = language;
    notifyListeners();
  }
  
  String get languageCode => _currentLanguage == AppLanguage.english ? 'en' : 'hi';
  
  // Get translated string
  String tr(String key) {
    final translations = _currentLanguage == AppLanguage.english 
        ? _englishStrings 
        : _hindiStrings;
    return translations[key] ?? key;
  }
  
  // English translations
  static const Map<String, String> _englishStrings = {
    // Home Screen
    'records': 'Records',
    'video_editing': 'Video Editing',
    'audio_operations': 'Audio Operations',
    'creative_tools': 'Creative Tools',
    'compress': 'Compress',
    'cut': 'Cut',
    'merge': 'Merge',
    'extract_audio': 'Extract Audio',
    'audio_on_video': 'Audio on Video',
    'photos_to_video': 'Photos to Video',
    'add_watermark': 'Add Watermark',
    'active': 'active',
    'done': 'done',
    
    // Settings Screen
    'settings': 'Settings',
    'theme': 'Theme',
    'language': 'Language',
    'storage': 'Storage',
    'total_storage_used': 'Total Storage Used',
    'temporary_files': 'Temporary Files',
    'output_files': 'Output Files',
    'files': 'files',
    'clear_temp': 'Clear Temp',
    'clear_all': 'Clear All',
    'about': 'About',
    'app_name': 'App Name',
    'version': 'Version',
    'built_with': 'Built with',
    'powered_by_ffmpeg': 'Powered by FFmpeg',
    'video_compression': 'Video Compression',
    'h264_encoding': 'H.264 encoding with adjustable quality',
    'lossless_cutting': 'Lossless Cutting',
    'stream_copy': 'Stream copy for fast trimming',
    'video_merging': 'Video Merging',
    'concat_filter': 'Concat filter with re-encoding',
    'audio_processing': 'Audio Processing',
    'extract_mix_add': 'Extract, mix, and add audio tracks',
    'slideshow_creation': 'Slideshow Creation',
    'xfade_transitions': 'Xfade transitions between images',
    'watermarking': 'Watermarking',
    'overlay_images_text': 'Overlay images and text',
    'clear_temporary_files': 'Clear Temporary Files',
    'clear_all_files': 'Clear All Files',
    'clear_temp_message': 'This will delete all temporary files. Output files will be kept.',
    'clear_all_message': 'This will delete all files including your processed videos and all job records. This cannot be undone.',
    'cancel': 'Cancel',
    'clear': 'Clear',
    'vixel_info': 'Vixel uses FFmpeg for video processing. All processing happens locally on your device.',
    
    // Records Screen
    'all': 'All',
    'completed': 'Completed',
    'clear_completed': 'Clear Completed',
    'clear_failed': 'Clear Failed',
    'no_jobs_yet': 'No jobs yet',
    'processing_history': 'Your processing history will appear here',
    'clear_completed_jobs': 'Clear Completed Jobs',
    'clear_completed_message': 'Are you sure you want to clear all completed jobs?',
    'clear_failed_jobs': 'Clear Failed Jobs',
    'clear_failed_message': 'Are you sure you want to clear all failed jobs?',
    'clear_all_jobs': 'Clear All Jobs',
    'clear_all_jobs_message': 'Are you sure you want to clear all jobs? This cannot be undone.',
    'delete_job': 'Delete Job',
    'delete_job_message': 'Are you sure you want to delete this job?',
    'confirm': 'Confirm',
    'delete': 'Delete',
    'job_cancelled': 'Job cancelled',
    
    // Compress Screen
    'compress_video': 'Compress Video',
    'compression_settings': 'Compression Settings',
    'resolution': 'Resolution',
    'output_resolution': 'Output video resolution',
    'video_bitrate': 'Video Bitrate',
    'bitrate_hint': 'Lower = smaller file, less quality',
    'compression_speed': 'Compression Speed',
    'speed_hint': 'Slower = better compression ratio',
    'audio_bitrate': 'Audio Bitrate',
    'audio_quality': 'Audio quality setting',
    'remove_audio': 'Remove Audio',
    'strip_audio': 'Strip audio track from video',
    'compression_started': 'Compression started! Check Records for progress.',
    
    // Cut Screen
    'cut_video': 'Cut Video',
    'cut_range': 'Cut Range',
    'start_time': 'Start Time',
    'end_time': 'End Time',
    'set_start': 'Set Start',
    'set_end': 'Set End',
    'preview_selected_range': 'Preview Selected Range',
    'quick_trim': 'Quick Trim',
    'first_10s': 'First 10s',
    'first_30s': 'First 30s',
    'last_10s': 'Last 10s',
    'last_30s': 'Last 30s',
    'cut_started': 'Cut started! Check Records for progress.',
    
    // Merge Screen
    'merge_videos': 'Merge Videos',
    'select_videos': 'Select Videos',
    'add_videos': 'Add Videos',
    'tap_to_add': 'Tap to add videos to merge',
    'output_settings': 'Output Settings',
    'merge_started': 'Merge started! Check Records for progress.',
    
    // Extract Audio Screen
    'extract_audio_title': 'Extract Audio',
    'output_format': 'Output Format',
    'audio_format': 'Audio file format',
    'extraction_started': 'Extraction started! Check Records for progress.',
    
    // Audio on Video Screen
    'audio_on_video_title': 'Audio on Video',
    'select_audio': 'Select Audio',
    'volume_settings': 'Volume Settings',
    'original_audio': 'Original Audio',
    'new_audio': 'New Audio',
    'video_duration': 'Video Duration',
    'audio_duration': 'Audio Duration',
    'audio_will_loop': 'Audio will loop to match video length',
    'add_audio_to_video': 'Add Audio to Video',
    'adding_audio': 'Adding audio to video. Check Records for progress.',
    
    // Photos to Video Screen
    'photos_to_video_title': 'Photos to Video',
    'add_photos': 'Add Photos',
    'select_images': 'Select images for your slideshow',
    'tap_to_add_more': 'Tap to add more photos',
    'photos': 'Photos',
    'total': 'Total',
    'background_music': 'Background Music (Optional)',
    'create_video': 'Create Video',
    'select_at_least_2': 'Select at least 2 photos',
    'creating_video': 'Creating video. Check Records for progress.',
    'max_photos': 'Maximum 20 photos allowed',
    'duration': 'Duration',
    'transition': 'Transition',
    
    // Add Watermark Screen
    'add_watermark_title': 'Add Watermark',
    'watermark_type': 'Watermark Type',
    'text': 'Text',
    'image': 'Image',
    'watermark_text': 'Watermark Text',
    'enter_watermark': 'Enter watermark text',
    'select_watermark_image': 'Select watermark image',
    'watermark_size': 'Watermark Size',
    'size_relative': 'Size relative to video width',
    'position': 'Position',
    'top_left': 'Top Left',
    'top_right': 'Top Right',
    'center': 'Center',
    'bottom_left': 'Bottom Left',
    'bottom_right': 'Bottom Right',
    'opacity': 'Opacity',
    'full_video': 'Full Video',
    'custom_range': 'Custom Range',
    'adding_watermark': 'Adding watermark. Check Records for progress.',
    
    // Play Video Screen
    'play_video': 'Play Video',
    'select_video': 'Select Video',
    
    // Common
    'error': 'Error',
    'success': 'Success',
    'processing': 'Processing',
    'pending': 'Pending',
    'failed': 'Failed',
    'cancelled': 'Cancelled',
    'original': 'Original',
    'auto': 'Auto',
  };
  
  // Hindi translations
  static const Map<String, String> _hindiStrings = {
    // Home Screen
    'records': 'रिकॉर्ड्स',
    'video_editing': 'वीडियो संपादन',
    'audio_operations': 'ऑडियो कार्य',
    'creative_tools': 'क्रिएटिव टूल्स',
    'compress': 'संपीड़ित करें',
    'cut': 'काटें',
    'merge': 'जोड़ें',
    'extract_audio': 'ऑडियो निकालें',
    'audio_on_video': 'वीडियो पर ऑडियो',
    'photos_to_video': 'फोटो से वीडियो',
    'add_watermark': 'वॉटरमार्क जोड़ें',
    'active': 'सक्रिय',
    'done': 'पूर्ण',
    
    // Settings Screen
    'settings': 'सेटिंग्स',
    'theme': 'थीम',
    'language': 'भाषा',
    'storage': 'स्टोरेज',
    'total_storage_used': 'कुल स्टोरेज उपयोग',
    'temporary_files': 'अस्थायी फ़ाइलें',
    'output_files': 'आउटपुट फ़ाइलें',
    'files': 'फ़ाइलें',
    'clear_temp': 'टेम्प साफ़ करें',
    'clear_all': 'सब साफ़ करें',
    'about': 'जानकारी',
    'app_name': 'ऐप का नाम',
    'version': 'संस्करण',
    'built_with': 'निर्मित',
    'powered_by_ffmpeg': 'FFmpeg द्वारा संचालित',
    'video_compression': 'वीडियो संपीड़न',
    'h264_encoding': 'समायोज्य गुणवत्ता के साथ H.264 एन्कोडिंग',
    'lossless_cutting': 'लॉसलेस कटिंग',
    'stream_copy': 'तेज़ ट्रिमिंग के लिए स्ट्रीम कॉपी',
    'video_merging': 'वीडियो मर्जिंग',
    'concat_filter': 'री-एन्कोडिंग के साथ कॉनकैट फ़िल्टर',
    'audio_processing': 'ऑडियो प्रोसेसिंग',
    'extract_mix_add': 'ऑडियो ट्रैक निकालें, मिक्स करें और जोड़ें',
    'slideshow_creation': 'स्लाइडशो निर्माण',
    'xfade_transitions': 'छवियों के बीच Xfade ट्रांज़िशन',
    'watermarking': 'वॉटरमार्किंग',
    'overlay_images_text': 'छवियों और टेक्स्ट को ओवरले करें',
    'clear_temporary_files': 'अस्थायी फ़ाइलें साफ़ करें',
    'clear_all_files': 'सभी फ़ाइलें साफ़ करें',
    'clear_temp_message': 'यह सभी अस्थायी फ़ाइलें हटा देगा। आउटपुट फ़ाइलें रखी जाएंगी।',
    'clear_all_message': 'यह आपके प्रोसेस किए गए वीडियो और सभी जॉब रिकॉर्ड सहित सभी फ़ाइलें हटा देगा। यह पूर्ववत नहीं किया जा सकता।',
    'cancel': 'रद्द करें',
    'clear': 'साफ़ करें',
    'vixel_info': 'Vixel वीडियो प्रोसेसिंग के लिए FFmpeg का उपयोग करता है। सभी प्रोसेसिंग आपके डिवाइस पर स्थानीय रूप से होती है।',
    
    // Records Screen
    'all': 'सभी',
    'completed': 'पूर्ण',
    'clear_completed': 'पूर्ण साफ़ करें',
    'clear_failed': 'विफल साफ़ करें',
    'no_jobs_yet': 'अभी कोई कार्य नहीं',
    'processing_history': 'आपका प्रोसेसिंग इतिहास यहाँ दिखाई देगा',
    'clear_completed_jobs': 'पूर्ण कार्य साफ़ करें',
    'clear_completed_message': 'क्या आप सभी पूर्ण कार्यों को साफ़ करना चाहते हैं?',
    'clear_failed_jobs': 'विफल कार्य साफ़ करें',
    'clear_failed_message': 'क्या आप सभी विफल कार्यों को साफ़ करना चाहते हैं?',
    'clear_all_jobs': 'सभी कार्य साफ़ करें',
    'clear_all_jobs_message': 'क्या आप सभी कार्यों को साफ़ करना चाहते हैं? यह पूर्ववत नहीं किया जा सकता।',
    'delete_job': 'कार्य हटाएं',
    'delete_job_message': 'क्या आप इस कार्य को हटाना चाहते हैं?',
    'confirm': 'पुष्टि करें',
    'delete': 'हटाएं',
    'job_cancelled': 'कार्य रद्द',
    
    // Compress Screen
    'compress_video': 'वीडियो संपीड़ित करें',
    'compression_settings': 'संपीड़न सेटिंग्स',
    'resolution': 'रेज़ोल्यूशन',
    'output_resolution': 'आउटपुट वीडियो रेज़ोल्यूशन',
    'video_bitrate': 'वीडियो बिटरेट',
    'bitrate_hint': 'कम = छोटी फ़ाइल, कम गुणवत्ता',
    'compression_speed': 'संपीड़न गति',
    'speed_hint': 'धीमा = बेहतर संपीड़न अनुपात',
    'audio_bitrate': 'ऑडियो बिटरेट',
    'audio_quality': 'ऑडियो गुणवत्ता सेटिंग',
    'remove_audio': 'ऑडियो हटाएं',
    'strip_audio': 'वीडियो से ऑडियो ट्रैक हटाएं',
    'compression_started': 'संपीड़न शुरू! प्रगति के लिए रिकॉर्ड्स देखें।',
    
    // Cut Screen
    'cut_video': 'वीडियो काटें',
    'cut_range': 'कट रेंज',
    'start_time': 'शुरू का समय',
    'end_time': 'समाप्ति का समय',
    'set_start': 'शुरू सेट करें',
    'set_end': 'समाप्ति सेट करें',
    'preview_selected_range': 'चयनित रेंज देखें',
    'quick_trim': 'त्वरित ट्रिम',
    'first_10s': 'पहले 10 सेकंड',
    'first_30s': 'पहले 30 सेकंड',
    'last_10s': 'अंतिम 10 सेकंड',
    'last_30s': 'अंतिम 30 सेकंड',
    'cut_started': 'कट शुरू! प्रगति के लिए रिकॉर्ड्स देखें।',
    
    // Merge Screen
    'merge_videos': 'वीडियो जोड़ें',
    'select_videos': 'वीडियो चुनें',
    'add_videos': 'वीडियो जोड़ें',
    'tap_to_add': 'मर्ज करने के लिए वीडियो जोड़ने के लिए टैप करें',
    'output_settings': 'आउटपुट सेटिंग्स',
    'merge_started': 'मर्ज शुरू! प्रगति के लिए रिकॉर्ड्स देखें।',
    
    // Extract Audio Screen
    'extract_audio_title': 'ऑडियो निकालें',
    'output_format': 'आउटपुट फॉर्मेट',
    'audio_format': 'ऑडियो फ़ाइल फॉर्मेट',
    'extraction_started': 'निष्कर्षण शुरू! प्रगति के लिए रिकॉर्ड्स देखें।',
    
    // Audio on Video Screen
    'audio_on_video_title': 'वीडियो पर ऑडियो',
    'select_audio': 'ऑडियो चुनें',
    'volume_settings': 'वॉल्यूम सेटिंग्स',
    'original_audio': 'मूल ऑडियो',
    'new_audio': 'नया ऑडियो',
    'video_duration': 'वीडियो अवधि',
    'audio_duration': 'ऑडियो अवधि',
    'audio_will_loop': 'ऑडियो वीडियो की लंबाई से मेल खाने के लिए लूप होगा',
    'add_audio_to_video': 'वीडियो में ऑडियो जोड़ें',
    'adding_audio': 'वीडियो में ऑडियो जोड़ रहे हैं। प्रगति के लिए रिकॉर्ड्स देखें।',
    
    // Photos to Video Screen
    'photos_to_video_title': 'फोटो से वीडियो',
    'add_photos': 'फोटो जोड़ें',
    'select_images': 'अपने स्लाइडशो के लिए छवियां चुनें',
    'tap_to_add_more': 'और फोटो जोड़ने के लिए टैप करें',
    'photos': 'फोटो',
    'total': 'कुल',
    'background_music': 'बैकग्राउंड म्यूज़िक (वैकल्पिक)',
    'create_video': 'वीडियो बनाएं',
    'select_at_least_2': 'कम से कम 2 फोटो चुनें',
    'creating_video': 'वीडियो बना रहे हैं। प्रगति के लिए रिकॉर्ड्स देखें।',
    'max_photos': 'अधिकतम 20 फोटो की अनुमति है',
    'duration': 'अवधि',
    'transition': 'ट्रांज़िशन',
    
    // Add Watermark Screen
    'add_watermark_title': 'वॉटरमार्क जोड़ें',
    'watermark_type': 'वॉटरमार्क प्रकार',
    'text': 'टेक्स्ट',
    'image': 'छवि',
    'watermark_text': 'वॉटरमार्क टेक्स्ट',
    'enter_watermark': 'वॉटरमार्क टेक्स्ट दर्ज करें',
    'select_watermark_image': 'वॉटरमार्क छवि चुनें',
    'watermark_size': 'वॉटरमार्क आकार',
    'size_relative': 'वीडियो चौड़ाई के सापेक्ष आकार',
    'position': 'स्थिति',
    'top_left': 'ऊपर बाएं',
    'top_right': 'ऊपर दाएं',
    'center': 'केंद्र',
    'bottom_left': 'नीचे बाएं',
    'bottom_right': 'नीचे दाएं',
    'opacity': 'पारदर्शिता',
    'full_video': 'पूरा वीडियो',
    'custom_range': 'कस्टम रेंज',
    'adding_watermark': 'वॉटरमार्क जोड़ रहे हैं। प्रगति के लिए रिकॉर्ड्स देखें।',
    
    // Play Video Screen
    'play_video': 'वीडियो चलाएं',
    'select_video': 'वीडियो चुनें',
    
    // Common
    'error': 'त्रुटि',
    'success': 'सफल',
    'processing': 'प्रोसेसिंग',
    'pending': 'लंबित',
    'failed': 'विफल',
    'cancelled': 'रद्द',
    'original': 'मूल',
    'auto': 'ऑटो',
  };
}


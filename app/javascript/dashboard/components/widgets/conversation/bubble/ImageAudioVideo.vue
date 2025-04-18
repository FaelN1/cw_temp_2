<script>
import { mapGetters } from 'vuex';
import { hasPressedCommand } from 'shared/helpers/KeyboardHelpers';
import GalleryView from '../components/GalleryView.vue';
import { timeStampAppendedURL } from 'dashboard/helper/URLHelper';

const ALLOWED_FILE_TYPES = {
  IMAGE: 'image',
  VIDEO: 'video',
  AUDIO: 'audio',
  IG_REEL: 'ig_reel',
};

export default {
  components: {
    GalleryView,
  },
  props: {
    attachment: {
      type: Object,
      required: true,
    },
    urlType: {
      type: String,
      required: false,
      default: 'data_url',
    },
  },
  emits: ['error'],
  data() {
    return {
      show: false,
      isImageError: false,
    };
  },
  computed: {
    ...mapGetters({
      currentChatAttachments: 'getSelectedChatAttachments',
    }),
    isImage() {
      return this.attachment.file_type === ALLOWED_FILE_TYPES.IMAGE;
    },
    isVideo() {
      return (
        this.attachment.file_type === ALLOWED_FILE_TYPES.VIDEO ||
        this.attachment.file_type === ALLOWED_FILE_TYPES.IG_REEL
      );
    },
    isAudio() {
      return this.attachment.file_type === ALLOWED_FILE_TYPES.AUDIO;
    },
    timeStampURL() {
      return timeStampAppendedURL(this.dataUrl);
    },
    attachmentTypeClasses() {
      return {
        image: this.isImage,
        video: this.isVideo,
      };
    },
    filteredCurrentChatAttachments() {
      const attachments = this.currentChatAttachments.filter(attachment =>
        ['image', 'video', 'audio'].includes(attachment.file_type)
      );
      return attachments;
    },
    dataUrl() {
      return this.attachment[this.urlType];
    },
    imageWidth() {
      return this.attachment.width ? `${this.attachment.width}px` : 'auto';
    },
    imageHeight() {
      return this.attachment.height ? `${this.attachment.height}px` : 'auto';
    },
  },
  watch: {
    attachment() {
      this.isImageError = false;
    },
  },
  methods: {
    onClose() {
      this.show = false;
    },
    onClick(e) {
      if (hasPressedCommand(e)) {
        window.open(this.attachment.data_url, '_blank');
        return;
      }
      this.show = true;
    },
    onImgError() {
      this.isImageError = true;
      this.$emit('error');
    },
  },
};
</script>

<template>
  <div class="message-text__wrap" :class="attachmentTypeClasses">
    <img
      v-if="isImage && !isImageError"
      class="bg-woot-200 dark:bg-woot-900"
      :src="dataUrl"
      :width="imageWidth"
      :height="imageHeight"
      @click="onClick"
      @error="onImgError"
    />
    <video
      v-if="isVideo"
      :src="dataUrl"
      muted
      playsInline
      @error="onImgError"
      @click="onClick"
    />
    <audio v-else-if="isAudio" controls class="skip-context-menu mb-0.5">
      <source :src="timeStampURL" />
    </audio>
    <GalleryView
      v-if="show"
      v-model:show="show"
      :attachment="attachment"
      :all-attachments="filteredCurrentChatAttachments"
      @error="onImgError"
      @close="onClose"
    />
  </div>
</template>

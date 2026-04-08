<script setup>
import { computed } from 'vue';
import Editor from '@tinymce/tinymce-vue';

import 'tinymce/tinymce';
import 'tinymce/icons/default';
import 'tinymce/models/dom';
import 'tinymce/themes/silver';
import 'tinymce/plugins/advlist';
import 'tinymce/plugins/autolink';
import 'tinymce/plugins/autoresize';
import 'tinymce/plugins/charmap';
import 'tinymce/plugins/code';
import 'tinymce/plugins/codesample';
import 'tinymce/plugins/fullscreen';
import 'tinymce/plugins/help';
import 'tinymce/plugins/image';
import 'tinymce/plugins/link';
import 'tinymce/plugins/lists';
import 'tinymce/plugins/preview';
import 'tinymce/plugins/searchreplace';
import 'tinymce/plugins/table';
import 'tinymce/plugins/template';
import 'tinymce/plugins/visualblocks';
import 'tinymce/plugins/wordcount';
import 'tinymce/skins/ui/oxide/skin.min.css';
import 'tinymce/skins/content/default/content.min.css';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  placeholder: {
    type: String,
    default: '',
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:modelValue']);

const content = computed({
  get: () => props.modelValue,
  set: value => emit('update:modelValue', value),
});

const editorConfig = computed(() => ({
  menubar: 'edit view insert format tools table help',
  skin: false,
  content_css: false,
  plugins:
    'advlist autolink autoresize charmap code codesample fullscreen help image link lists preview searchreplace table template visualblocks wordcount',
  toolbar:
    'undo redo | blocks | bold italic underline strikethrough | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | blockquote | link image table codesample template | searchreplace visualblocks code fullscreen preview',
  toolbar_mode: 'sliding',
  min_height: 420,
  autoresize_bottom_margin: 16,
  placeholder: props.placeholder,
  branding: false,
  promotion: false,
  statusbar: true,
  resize: true,
  convert_urls: false,
  forced_root_block: 'p',
  browser_spellcheck: true,
  contextmenu: 'link image table',
  templates: [
    {
      title: 'Tip / Consejo',
      description: 'Insert a highlighted tip block',
      content:
        '<div class="hc-block hc-block-info"><p><strong>Consejo:</strong> agrega aquí una recomendación rápida para el cliente.</p></div>',
    },
    {
      title: 'Warning / Advertencia',
      description: 'Insert an important warning block',
      content:
        '<div class="hc-block hc-block-warning"><p><strong>Importante:</strong> agrega aquí una advertencia clara para evitar errores.</p></div>',
    },
    {
      title: 'Success / Resultado',
      description: 'Insert a success/result block',
      content:
        '<div class="hc-block hc-block-success"><p><strong>Resultado esperado:</strong> explica qué debería ocurrir si el usuario sigue los pasos.</p></div>',
    },
    {
      title: 'CTA / Siguiente paso',
      description: 'Insert a call-to-action block',
      content:
        '<div class="hc-block hc-block-cta"><p><strong>Siguiente paso:</strong> agrega un enlace o instrucción para continuar.</p></div>',
    },
  ],
  content_style:
    'body { font-family: Inter, -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif; font-size: 16px; line-height: 1.7; color: #0f172a; max-width: 860px; margin: 0 auto; padding: 1.25rem 1rem 2rem; } p { margin: 0 0 1rem 0; }',
}));
</script>

<template>
  <div
    class="pl-4 pb-10 rtl:pr-4 rtl:pl-0"
    :class="{ 'opacity-70 pointer-events-none': disabled }"
  >
    <Editor
      v-model="content"
      :disabled="disabled"
      license-key="gpl"
      :init="editorConfig"
    />
  </div>
</template>

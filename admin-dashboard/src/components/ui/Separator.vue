<template>
  <div
    :class="cn('shrink-0 bg-border', props.orientation === 'horizontal' ? 'h-[1px] w-full' : 'h-full w-[1px]', props.class)"
    v-bind="$attrs"
  />
</template>

<script setup>
import { cn } from "@/lib/utils";

const props = defineProps({
  orientation: {
    type: String,
    default: "horizontal",
    validator: (value) => value === "horizontal" || value === "vertical",
  },
  decorative: {
    type: Boolean,
    default: true,
  },
  class: {
    type: String,
    default: "",
  },
});
</script>

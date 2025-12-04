<template>
  <MenubarRoot
    v-bind="forwarded"
    :class="cn('flex h-10 items-center space-x-1 rounded-md border bg-background p-1', props.class)"
  >
    <slot />
  </MenubarRoot>
</template>

<script setup>
import { cn } from "@/lib/utils";
import { MenubarRoot, useForwardProps } from "radix-vue";
import { computed } from "vue";

const props = defineProps({
  class: { type: String, default: "" },
  modelValue: { type: null, default: undefined },
});

const forwarded = useForwardProps(
  computed(() => {
    const { class: _, ...delegated } = props;
    return delegated;
  })
);
</script>

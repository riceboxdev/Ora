<template>
  <MenubarMenu v-bind="forwarded">
    <slot />
  </MenubarMenu>
</template>

<script setup>
import { MenubarMenu, useForwardProps } from "radix-vue";
import { computed } from "vue";

const props = defineProps({
  value: { type: String, required: false },
});

const forwarded = useForwardProps(
  computed(() => {
    const { ...delegated } = props;
    return delegated;
  })
);
</script>

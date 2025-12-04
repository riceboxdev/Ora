<template>
  <MenubarItem
    v-bind="forwarded"
    :class="
      cn(
        'relative flex cursor-default select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50',
        inset && 'pl-8',
        props.class
      )
    "
  >
    <slot />
  </MenubarItem>
</template>

<script setup>
import { cn } from "@/lib/utils";
import { MenubarItem, useForwardProps } from "radix-vue";
import { computed } from "vue";

const props = defineProps({
  class: { type: String, default: "" },
  inset: { type: Boolean, default: false },
});

const forwarded = useForwardProps(
  computed(() => {
    const { class: _, ...delegated } = props;
    return delegated;
  })
);
</script>

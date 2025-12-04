<template>
  <MenubarTrigger
    v-bind="forwarded"
    :class="
      cn(
        'flex cursor-default select-none items-center rounded-sm px-3 py-1.5 text-sm font-medium outline-none focus:bg-accent focus:text-accent-foreground data-[state=open]:bg-accent data-[state=open]:text-accent-foreground',
        inset && 'pl-8',
        props.class
      )
    "
  >
    <slot />
  </MenubarTrigger>
</template>

<script setup>
import { cn } from "@/lib/utils";
import { MenubarTrigger, useForwardProps } from "radix-vue";
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

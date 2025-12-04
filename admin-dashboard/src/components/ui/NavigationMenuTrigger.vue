<template>
  <NavigationMenuTrigger
    :class="cn(
      'group inline-flex h-10 w-max items-center justify-center rounded-md bg-background px-4 py-2 text-sm font-medium transition-colors hover:bg-accent hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground focus:outline-none disabled:pointer-events-none disabled:opacity-50 data-[active]:bg-accent/50 data-[state=open]:bg-accent/50',
      props.class
    )"
    v-bind="$attrs"
  >
    <slot />
  </NavigationMenuTrigger>
</template>

<script setup>
import { cn } from "@/lib/utils";
import { NavigationMenuTrigger } from "radix-vue";

const props = defineProps({
  class: {
    type: String,
    default: "",
  },
});
</script>

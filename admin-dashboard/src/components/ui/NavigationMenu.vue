<template>
  <NavigationMenuRoot v-bind="$attrs">
    <NavigationMenuList :class="cn('group flex flex-1 list-none items-center justify-center space-x-1', props.class)">
      <slot />
    </NavigationMenuList>
    <NavigationMenuViewport class="absolute left-0 top-full flex justify-center" />
  </NavigationMenuRoot>
</template>

<script setup>
import { cn } from "@/lib/utils";
import {
  NavigationMenuRoot,
  NavigationMenuList,
  NavigationMenuViewport,
} from "radix-vue";

const props = defineProps({
  class: {
    type: String,
    default: "",
  },
});
</script>

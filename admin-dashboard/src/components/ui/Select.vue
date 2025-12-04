<template>
  <SelectRoot v-bind="forwarded">
    <SelectTrigger
      :class="
        cn(
          'flex h-10 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 [&>span]:line-clamp-1',
          props.class
        )
      "
    >
      <SelectValue :placeholder="placeholder" />
      <SelectIcon as-child>
        <ChevronDown class="h-4 w-4 opacity-50" />
      </SelectIcon>
    </SelectTrigger>
    <SelectPortal>
      <SelectContent
        :class="
          cn(
            'relative z-50 min-w-[8rem] overflow-hidden rounded-md border bg-popover text-popover-foreground shadow-md data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2',
            position === 'popper' &&
              'data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1',
            props.class
          )
        "
        :position="position"
        :side-offset="sideOffset"
      >
        <SelectViewport class="p-1">
          <slot />
        </SelectViewport>
      </SelectContent>
    </SelectPortal>
  </SelectRoot>
</template>

<script setup>
import { cn } from "@/lib/utils";
import { ChevronDown } from "lucide-vue-next";
import {
  SelectContent,
  SelectIcon,
  SelectPortal,
  SelectRoot,
  SelectTrigger,
  SelectValue,
  SelectViewport,
  useForwardProps,
} from "radix-vue";
import { computed } from "vue";

const props = defineProps({
  placeholder: { type: String, default: "Select an option" },
  class: { type: String, default: "" },
  position: { type: String, default: "popper" },
  sideOffset: { type: Number, default: 4 },
});

const forwarded = useForwardProps(
  computed(() => {
    const { class: _, ...delegated } = props;
    return delegated;
  })
);
</script>

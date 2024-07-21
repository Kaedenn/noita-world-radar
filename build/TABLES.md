# Table Layouts

There are various tables used to store structured information. This document serves as a quick reference guide to their layouts and usage.

## Line

This is the argument to `Panel:p`, `Panel:d`, `Panel:draw_line`, etc.

The Panel class supports fairly complex layout for printing lines using the
`Panel:p()` and `Panel:d()` functions. A line is either a string or a table of
line fragments. Each line fragment can be either a string or another table.
The following values are understood for line fragments; all attributes are
optional:
```
  level: string       used to determine color and displayed as a prefix
  color: string       one of Panel.colors; or:
  color: {r, g, b}    values between [0, 1], alpha = 1; or:
  color: {r, g, b, a} values between [0, 1]
  image: string       path to a PNG image file
  width: number       override width of the image in pixels
  height: number      override height of the image in pixels
  wrapped_text: string    display text wrapped to the container
  separator_text: string  display text with a separator
  label_text: string      display text as a label
  bullet_text: string     display text with a bullet
  button: table       add a button to the left of the entry
    .text: string     button text (default: "Button")
    .id: string       optional button ID, if button.text lacks one
    .func: function   function called if the button is clicked
    .small: boolean   if true, creates a small button
    [i]: any          applied to the function as arguments
```

The indexed values (`fragment[1]`, `fragment[2]`, etc) can be zero or more of the
following:
```
  string              displayed as is
  Line                processed as above with results on one line
  LineFragment        processed as above with results on one line
```

The following labels are understood:
```
  "debug"             color={0.9, 0.9, 0}, near-yellow
  "warning"           color={1.0, 0.5, 0.5}, light-red
```

When displaying images via `Line.image`, the width and height keys can be used
to override the image width and height. For instance:
```
  {"mods/mymod/files/myimage.png", height=20}
```
will display the image using its actual width but with a height of 20 pixels
Proportional scaling and min/max sizes are not (yet?) supported.

Button functions are called as follows:
```
  button_func(unpack(button_args), panel, imgui)
```
where panel is the host Panel instance and imgui is the current ImGui object.

`Panel.separator` is a special Line that prints a horizontal separator, used
as follows:
```
  host:p(host.separator)
```

## Image

This is the `info.lua`-specific image layout.

While the line format doesn't allow for much control over images, the purpose-built `InfoPanel:_draw_image` function provides much more control.

Images are either strings (paths to the image file) or tables with the following entries, all of which optional (aside from the file path):
```
  path:string         path to the image asset
  width:number        image width override, in pixels
  height:number       image height override, in pixels
  frame_width:number  width of a single sprite cell in multi-sprite images
  frame_height:number height of a single sprite cell in multi-sprite images
```

Passing 0 for width or height is the same as omitting them.

## Spell List Entry

This is the layout of `info.env.spell_list`.

```
  id:string           uppercase spell ID
  name:string         display name (eg. $action_chain_bolt, $action_bomb, etc.)
  icon:string         path to spell UI icon, or:
  icon:table          spell icon image definition; see above
  config:table        arbitrary table for configuration
    .keep:number      if 1, keep spell on pickup
    .ignore_ac:boolean  if true, ignore wands that Always Cast this spell
```

## Enemy List Entry

This is the layout of `info.env.entity_list`.

```
  id:string           unique entity ID
  name:string         entity name (eg. $animal_worm, etc.)
  path:string         path to the entity XML file
  icon:string         path to the entity icon, if one exists, or:
  icon:table          entity icon image definition; see above
  config:table        arbitrary table for configuration
```

## Material List Entry

This is the layout of `info.env.material_list`.

```
  kind:string         one of "liquid", "sand", "gas", "fire", "solid"
  id:number           unique numeric type
  name:string         unique internal material name
  uiname:string       display name (eg. $mat_water, $mat_gold, etc.)
  locname:string      display name, but localized
  icon:string         path to material icon, if one exists, or:
  icon:table          material icon image definition; see above
  tags:{string}       material tags as a table of strings
  config:table        arbitrary table for configuration
    .keep:number      if 1, keep material on pickup
```

## Item List Entry

This is the layout of `info.env.item_list`.

```
  id:string           unique item ID
  name:string         item name (eg. $item_treasure_chest_super, etc.)
  path:string         path to the item XML file
  icon:string         path to the item icon, or:
  icon:table          item icon image definition; see above
```


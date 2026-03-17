# Deferred Kernel Modules

## uinput

User-space input device creation. Needed for:
- Mouse button remap (Razer Viper Mini evdev script)
- Sunshine game streaming (remote input injection)

To enable: add `uinput` to `/etc/modules-load.d/uinput.conf`

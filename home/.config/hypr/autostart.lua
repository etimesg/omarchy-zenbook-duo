-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- ASUS Zenbook Duo: turn off the base screen when the keyboard is docked
-- over it (see ~/.local/bin/zenbook-duo-screen).
o.exec_on_start("zenbook-duo-screen")

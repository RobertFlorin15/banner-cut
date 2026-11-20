#include "my_application.h"

namespace {

void use_x11_if_wayland_font_schema_is_incomplete() {
  const char* display = g_getenv("DISPLAY");
  const char* backend = g_getenv("GDK_BACKEND");
  if (display == nullptr || *display == '\0' ||
      (backend != nullptr && *backend != '\0' &&
       !g_str_equal(backend, "wayland") && !g_str_equal(backend, "*"))) {
    return;
  }

  GSettingsSchemaSource* source = g_settings_schema_source_get_default();
  if (source == nullptr) return;

  g_autoptr(GSettingsSchema) desktop =
      g_settings_schema_source_lookup(source, "org.gnome.desktop.interface", TRUE);
  g_autoptr(GSettingsSchema) xsettings = g_settings_schema_source_lookup(
      source, "org.gnome.settings-daemon.plugins.xsettings", TRUE);

  // GTK 3 on Wayland reads all three font keys after choosing a schema.
  // A mixed Snap and host schema set can make that recursive lookup incomplete.
  const bool use_desktop = desktop != nullptr &&
      g_settings_schema_has_key(desktop, "font-antialiasing");
  GSettingsSchema* schema = use_desktop ? desktop : xsettings;
  if (schema == nullptr) return;
  if (!g_settings_schema_has_key(
          schema, use_desktop ? "font-antialiasing" : "antialiasing") ||
      !g_settings_schema_has_key(schema, use_desktop ? "font-hinting" : "hinting") ||
      !g_settings_schema_has_key(schema,
                                use_desktop ? "font-rgba-order" : "rgba-order")) {
    g_message("GNOME font settings are incomplete. Starting BannerCut with X11.");
    g_setenv("GDK_BACKEND", "x11", TRUE);
  }
}

}  // namespace

int main(int argc, char** argv) {
  use_x11_if_wayland_font_schema_is_incomplete();
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}

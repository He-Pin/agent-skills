import { NavLink, Outlet } from "react-router-dom";
import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { getVersion } from "@tauri-apps/api/app";

import { open } from "@tauri-apps/plugin-dialog";
import { LayoutDashboard, Puzzle, Store, Settings, GitBranch, FolderOpen } from "lucide-react";
import logoUrl from "@/assets/logo.png";
import { Button } from "@/components/ui/button";
import ImportRepoDialog from "@/components/ImportRepoDialog";
import { useResizable } from "@/hooks/useResizable";
import ResizeHandle from "@/components/ResizeHandle";
import { useAddLocalDir } from "@/hooks/useRepos";

export default function Layout() {
  const { t } = useTranslation();
  const [appVersion, setAppVersion] = useState<string>("");
  const [showImport, setShowImport] = useState(false);
  const addLocalDir = useAddLocalDir();


  async function handleImportLocal() {
    const selected = await open({ directory: true, multiple: false });
    if (selected) {
      try {
        await addLocalDir.mutateAsync(selected);
      } catch (e) {
        console.error("Import local failed:", e instanceof Error ? e.message : String(e));
      }
    }
  }

  const navItems = [
    { to: "/", icon: LayoutDashboard, label: t("sidebar.dashboard") },
    { to: "/skills", icon: Puzzle, label: t("sidebar.skills") },
    { to: "/marketplace", icon: Store, label: t("sidebar.marketplace") },
    { to: "/settings", icon: Settings, label: t("sidebar.settings") },
  ];

  useEffect(() => {
    let active = true;
    getVersion()
      .then((version) => {
        if (active) {
          setAppVersion(version);
        }
      })
      .catch(() => {
        if (active) {
          setAppVersion("");
        }
      });
    return () => {
      active = false;
    };
  }, []);

  const sidebar = useResizable({
    initial: 200,
    min: 140,
    max: 320,
    storageKey: "sidebar-width",
  });

  return (
    <div className="relative flex h-screen overflow-hidden bg-background">

      {/* Sidebar */}
      <aside
        className="flex shrink-0 flex-col bg-sidebar"
        style={{ width: sidebar.width }}
      >
        {/* Logo area */}
        <div
          className="shrink-0 flex items-end px-4 pb-3 pt-4"
        >
          <span className="flex items-center gap-3 pointer-events-none select-none">
            <img src={logoUrl} alt="" className="size-8 rounded-lg" />
            <span className="text-lg font-semibold text-sidebar-foreground">
              AgentSkills
            </span>
          </span>
        </div>

        {/* Import buttons */}
        <div className="px-3 pb-1 space-y-1">
          <Button
            variant="outline"
            size="sm"
            className="w-full justify-start gap-2 border-dashed"
            onClick={() => setShowImport(true)}
          >
            <GitBranch className="size-3.5" />
            {t("repos.importRepo")}
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="w-full justify-start gap-2 border-dashed"
            disabled={addLocalDir.isPending}
            onClick={handleImportLocal}
          >
            <FolderOpen className="size-3.5" />
            {t("repos.importLocal")}
          </Button>
        </div>

        {/* Nav links */}
        <nav className="flex flex-1 flex-col gap-1 p-3">
          {navItems.map(({ to, icon: Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              end={to === "/"}
              className={({ isActive }) =>
                `flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                  isActive
                    ? "bg-sidebar-accent text-sidebar-accent-foreground"
                    : "text-sidebar-foreground/70 hover:bg-sidebar-accent/50 hover:text-sidebar-foreground"
                }`
              }
            >
              <Icon className="size-4" />
              {label}
            </NavLink>
          ))}
        </nav>

        {/* Footer */}
        <div className="border-t border-sidebar-border px-5 py-3">
          <p className="text-xs text-muted-foreground">
            {appVersion ? `v${appVersion}` : "v--"}
          </p>
        </div>
      </aside>

      <ResizeHandle onMouseDown={sidebar.onMouseDown} />

      {/* Main content */}
      <main className="flex-1 min-w-0 relative overflow-y-auto">
        <Outlet />
      </main>

      {showImport && <ImportRepoDialog onClose={() => setShowImport(false)} />}
    </div>
  );
}

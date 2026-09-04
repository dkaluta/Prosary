"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ComponentProps } from "react";

type RouteAwareLinkProps = ComponentProps<typeof Link> & {
  currentFor?: readonly string[];
};

export function RouteAwareLink({ currentFor, href, ...props }: RouteAwareLinkProps) {
  const pathname = usePathname();
  const hrefPath = typeof href === "string" ? href : href.pathname;
  const currentPaths = currentFor ?? (hrefPath ? [hrefPath] : []);
  const isCurrent = currentPaths.some((path) =>
    path === "/" ? pathname === path : pathname === path || pathname.startsWith(`${path}/`),
  );

  return <Link {...props} href={href} aria-current={isCurrent ? "page" : undefined} />;
}

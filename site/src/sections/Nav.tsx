import { useEffect, useState } from "react"
import { LuGithub } from "react-icons/lu"
import { REPO, asset } from "@/lib/site"
import { cn } from "@/lib/utils"

const links = [["How it works", "#how"], ["Features", "#features"], ["Screens", "#screens"], ["Install", "#install"], ["FAQ", "#faq"]]

export function Nav() {
  const [scrolled, setScrolled] = useState(false)
  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 12)
    on(); window.addEventListener("scroll", on, { passive: true })
    return () => window.removeEventListener("scroll", on)
  }, [])
  return (
    <header className="fixed inset-x-0 top-3 z-50 px-3">
      <nav className={cn("mx-auto flex max-w-5xl items-center justify-between rounded-full border px-3 py-2 transition-all duration-300 sm:px-4",
        scrolled ? "border-white/10 bg-[#0d0c14]/80 backdrop-blur-xl" : "border-transparent bg-transparent")}>
        <a href="#top" className="flex items-center gap-2.5">
          <img src={asset("icon.png")} alt="" className="h-8 w-8 rounded-[9px]" />
          <span className="text-[14px] font-normal">NoBars</span>
        </a>
        <div className="hidden items-center gap-1 md:flex">
          {links.map(([l, h]) => (
            <a key={h} href={h} className="rounded-full px-3 py-1.5 text-[14px] text-white/60 transition hover:bg-white/5 hover:text-white">{l}</a>
          ))}
        </div>
        <a href={REPO} target="_blank" rel="noreferrer"
          className="flex items-center gap-2 rounded-full bg-white px-3.5 py-1.5 text-[14px] font-medium text-black transition hover:bg-white/85">
          <LuGithub className="h-4 w-4" /> GitHub
        </a>
      </nav>
    </header>
  )
}

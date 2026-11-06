import { REPO, asset } from "@/lib/site"

export function Footer() {
  return (
    <footer className="mx-auto max-w-6xl px-5 pb-12 sm:px-8">
      <div className="flex flex-col items-start justify-between gap-6 border-t border-line pt-8 sm:flex-row sm:items-center">
        <div className="flex items-center gap-3">
          <img src={asset("icon.png")} alt="" className="h-9 w-9 rounded-[10px]" />
          <div>
            <div className="text-[14px] font-normal">NoBars</div>
            <div className="text-[13px] text-white/45">Built by Swastik Dutt</div>
          </div>
        </div>
        <div className="flex gap-5 text-[14px] text-white/55">
          <a href={REPO} target="_blank" rel="noreferrer" className="hover:text-white">GitHub</a>
          <a href="#install" className="hover:text-white">Install</a>
          <a href="#faq" className="hover:text-white">FAQ</a>
        </div>
      </div>
    </footer>
  )
}

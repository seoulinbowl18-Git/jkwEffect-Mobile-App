import { STATUS } from "@/lib/api";

export const StatCard = ({ label, value, sub, big, testid, children }) => (
  <div data-testid={testid} className="bg-white rounded-2xl border border-slate-200 p-5 sm:p-6">
    <p className="text-sm text-slate-600 font-medium">{label}</p>
    <p className={`${big ? "text-2xl sm:text-4xl" : "text-xl sm:text-2xl"} break-words font-extrabold tracking-tight mt-2`} data-testid={testid && `${testid}-value`}>{value}</p>
    {sub && <p className="text-xs text-slate-500 mt-2">{sub}</p>}
    {children}
  </div>
);

export const StatusBadge = ({ s }) => {
  const m = STATUS[s] || { label: s, cls: "bg-slate-100" };
  return <span className={`inline-block px-2.5 py-1 rounded-full text-xs font-semibold whitespace-nowrap ${m.cls}`}>{m.label}</span>;
};

export const Chips = ({ items, value, onChange, prefix }) => (
  <div className="flex gap-2 flex-wrap">
    {items.map(([k, label]) => (
      <button key={k} data-testid={`${prefix}-${k || "all"}`} onClick={() => onChange(k)}
        className={`h-9 px-3.5 rounded-lg text-sm font-semibold border transition-colors ${value === k ? "bg-slate-900 text-white border-slate-900" : "bg-white border-slate-200 hover:bg-slate-50"}`}>
        {label}
      </button>
    ))}
  </div>
);

export const Tabs = ({ items, value, onChange, prefix }) => (
  <div className="inline-flex p-1 rounded-xl bg-slate-100 gap-1 overflow-x-auto max-w-full">
    {items.map(([k, label]) => (
      <button key={k} data-testid={`${prefix}-${k}`} onClick={() => onChange(k)}
        className={`h-10 px-4 rounded-lg text-sm font-semibold whitespace-nowrap transition-colors ${value === k ? "bg-white shadow-sm text-slate-900" : "text-slate-600 hover:text-slate-900"}`}>
        {label}
      </button>
    ))}
  </div>
);

export const Empty = ({ title, desc, children }) => (
  <div className="bg-white rounded-2xl border border-slate-200 py-14 px-6 text-center" data-testid="empty-state">
    <p className="font-bold">{title}</p>
    <p className="text-sm text-slate-500 mt-1 max-w-sm mx-auto">{desc}</p>
    {children && <div className="mt-5">{children}</div>}
  </div>
);

export const Field = ({ label, children }) => (
  <label className="block">
    <span className="text-sm font-semibold text-slate-700">{label}</span>
    <div className="mt-1.5">{children}</div>
  </label>
);

export const inputCls = "w-full h-11 px-3.5 rounded-xl border border-slate-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#FF5500]";

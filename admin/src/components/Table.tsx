import { useEffect, useState, type ReactNode } from 'react'
import { CaretLeftIcon, CaretRightIcon } from '@phosphor-icons/react'
import { Checkbox, cx } from './ui'
import { num } from '../lib/format'

export interface Column<T> {
  key: string
  header: ReactNode
  cell: (row: T) => ReactNode
  align?: 'left' | 'right' | 'center'
  width?: string
  className?: string
}

export function DataTable<T>({
  columns, rows, rowKey, onRowClick, activeKey, pageSize = 25, empty, selectable, selected, onSelect, footer, dense,
}: {
  columns: Column<T>[]
  rows: T[]
  rowKey: (row: T) => string
  onRowClick?: (row: T) => void
  activeKey?: string | null
  pageSize?: number
  empty?: ReactNode
  selectable?: (row: T) => boolean
  selected?: Set<string>
  onSelect?: (next: Set<string>) => void
  footer?: ReactNode
  dense?: boolean
}) {
  const [page, setPage] = useState(0)
  const pages = Math.max(1, Math.ceil(rows.length / pageSize))
  useEffect(() => {
    if (page > pages - 1) setPage(0)
  }, [pages, page])
  const slice = rows.slice(page * pageSize, page * pageSize + pageSize)
  const canSelect = !!(selectable && selected && onSelect)
  const selectableRows = canSelect ? slice.filter((r) => selectable!(r)) : []
  const allOn = canSelect && selectableRows.length > 0 && selectableRows.every((r) => selected!.has(rowKey(r)))
  const someOn = canSelect && selectableRows.some((r) => selected!.has(rowKey(r)))

  return (
    <div className="bg-surface border border-line rounded-[var(--radius-card)] overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full border-collapse text-[13.5px]">
          <thead>
            <tr className="bg-sunken border-b border-line">
              {canSelect && (
                <th className="w-10 pl-4">
                  <Checkbox
                    label="Select all on this page"
                    checked={allOn}
                    indeterminate={!allOn && someOn}
                    onChange={(v) => {
                      const next = new Set(selected)
                      selectableRows.forEach((r) => (v ? next.add(rowKey(r)) : next.delete(rowKey(r))))
                      onSelect!(next)
                    }}
                  />
                </th>
              )}
              {columns.map((c) => (
                <th key={c.key} scope="col" style={{ width: c.width }} className={cx('h-9 px-4 text-[12px] font-semibold text-muted whitespace-nowrap', c.align === 'right' ? 'text-right' : c.align === 'center' ? 'text-center' : 'text-left')}>
                  {c.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {slice.map((row) => {
              const k = rowKey(row)
              const active = activeKey === k
              return (
                <tr
                  key={k}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                  onKeyDown={onRowClick ? (e) => { if (e.key === 'Enter') onRowClick(row) } : undefined}
                  tabIndex={onRowClick ? 0 : undefined}
                  className={cx('border-b border-line-2 last:border-b-0 transition-colors', onRowClick && 'cursor-pointer hover:bg-hover focus-visible:bg-hover', active && 'bg-brand-tint/60 hover:bg-brand-tint/70')}
                >
                  {canSelect && (
                    <td className="pl-4 w-10">
                      {selectable!(row) && (
                        <Checkbox
                          label="Select row"
                          checked={selected!.has(k)}
                          onChange={(v) => {
                            const next = new Set(selected)
                            if (v) next.add(k)
                            else next.delete(k)
                            onSelect!(next)
                          }}
                        />
                      )}
                    </td>
                  )}
                  {columns.map((c) => (
                    <td key={c.key} className={cx('px-4 align-middle', dense ? 'h-11' : 'h-[52px]', c.align === 'right' ? 'text-right' : c.align === 'center' ? 'text-center' : 'text-left', c.className)}>
                      {c.cell(row)}
                    </td>
                  ))}
                </tr>
              )
            })}
          </tbody>
        </table>
        {rows.length === 0 && <div className="border-t border-line-2">{empty}</div>}
      </div>
      {(rows.length > pageSize || footer) && (
        <div className="flex items-center gap-3 px-4 h-12 border-t border-line text-[12.5px] text-muted">
          <div className="flex-1">{footer}</div>
          {rows.length > pageSize && (
            <>
              <span className="num">
                {num(page * pageSize + 1)}–{num(Math.min(rows.length, (page + 1) * pageSize))} of {num(rows.length)}
              </span>
              <div className="flex items-center gap-1">
                <button type="button" aria-label="Previous page" disabled={page === 0} onClick={() => setPage((p) => p - 1)} className="w-8 h-8 rounded-lg inline-flex items-center justify-center border border-line bg-surface hover:bg-hover disabled:opacity-40">
                  <CaretLeftIcon size={14} weight="bold" />
                </button>
                <button type="button" aria-label="Next page" disabled={page >= pages - 1} onClick={() => setPage((p) => p + 1)} className="w-8 h-8 rounded-lg inline-flex items-center justify-center border border-line bg-surface hover:bg-hover disabled:opacity-40">
                  <CaretRightIcon size={14} weight="bold" />
                </button>
              </div>
            </>
          )}
        </div>
      )}
    </div>
  )
}

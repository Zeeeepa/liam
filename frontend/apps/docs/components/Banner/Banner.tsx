'use client'

import { X } from 'lucide-react'
import Link from 'next/link'
import {
  type FC,
  type HTMLAttributes,
  type PropsWithChildren,
  useCallback,
  useEffect,
  useState,
} from 'react'
import { tv } from 'tailwind-variants'
import { match } from 'ts-pattern'
import { JackAnimationForDark } from './JackAnimationForDark'
import { JackAnimationForLight } from './JackAnimationForLight'

const HEIGHT = '3rem'

type Props = PropsWithChildren &
  HTMLAttributes<HTMLDivElement> & {
    variant: 'light' | 'dark'
    link: string
    ancherComponent: 'a' | 'Link'
  }

export const Banner: FC<Props> = ({
  variant,
  id,
  link,
  ancherComponent = "Link",
  children,
  ...props
}) => {
  const [open, setOpen] = useState(true)
  const globalKey = id ? `nd-banner-${id}` : null

  useEffect(() => {
    if (globalKey) setOpen(localStorage.getItem(globalKey) !== 'true')
  }, [globalKey])

  const onClick = useCallback(() => {
    setOpen(false)
    if (globalKey) localStorage.setItem(globalKey, 'true')
  }, [globalKey])

  const wrapperStyle = tv({
    base: 'sticky top-0 z-40 flex h-[var(--fd-banner-height)] items-center justify-center px-4 bg-[url("/images/banner_bg.png")] bg-blend-overlay',
    variants: {
      variant: {
        light: 'bg-liam-green-300',
        dark: 'bg-liam-green-700',
      },
    },
  })

  const textStyle = tv({
    base: 'text-sm font-mono font-medium',
    variants: {
      variant: {
        light: 'text-base-black',
        dark: 'text-liam-green-400',
      },
    },
  })

  const linkStyle = tv({
    base: 'py-0.5 px-2 text-base-black text-xs font-medium font-mono hover:underline',
    variants: {
      variant: {
        light: 'bg-base-white',
        dark: 'bg-liam-green-400',
      },
    },
  })

  const buttonStyle = tv({
    base: 'absolute end-2 top-1/2 -translate-y-1/2',
    variants: {
      variant: {
        light: 'text-base-black',
        dark: 'text-liam-green-400',
      },
    },
  })

  if (!open) return null

  return (
    <div id={id} {...props} className={wrapperStyle({ variant })}>
      {open && (
        <style>
          {globalKey
            ? `:root:not(.${globalKey}) { --fd-banner-height: ${HEIGHT}; }`
            : `:root { --fd-banner-height: ${HEIGHT}; }`}
        </style>
      )}
      {globalKey && (
        <>
          <style>{`.${globalKey} #${id} { display: none; }`}</style>
          <script
            // biome-ignore lint/security/noDangerouslySetInnerHtml: <explanation>
            dangerouslySetInnerHTML={{
              __html: `if (localStorage.getItem('${globalKey}') === 'true') document.documentElement.classList.add('${globalKey}');`,
            }}
          />
        </>
      )}
      <div className="flex items-center gap-6">
        <div className="flex items-center gap-4">
          {match(variant)
            .with('light', () => <JackAnimationForLight />)
            .with('dark', () => <JackAnimationForDark />)
            .exhaustive()}
          <p className={textStyle({ variant })}>
            <span>{'< '}</span>
            {children}
          </p>
        </div>
        {ancherComponent === 'a' && (
          <a href={link} className={linkStyle({ variant })}>
            Learn More
          </a>
        )}
        {ancherComponent === 'Link' && (
          <Link href={link} className={linkStyle({ variant })}>
            Learn More
          </Link>
        )}
      </div>
      {id && (
        <button
          type="button"
          aria-label="Close Banner"
          className={buttonStyle({ variant })}
          onClick={onClick}
        >
          <X className="w-6 h-6" />
        </button>
      )}
    </div>
  )
}

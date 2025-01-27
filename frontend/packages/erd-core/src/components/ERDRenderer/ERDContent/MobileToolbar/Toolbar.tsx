import { Ellipsis } from '@liam-hq/ui'
import * as ToolbarPrimitive from '@radix-ui/react-toolbar'
import { useState } from 'react'
import type { FC } from 'react'
import styles from './Toolbar.module.css'
import { ZoomControls } from './ZoomControls'

export const Toolbar: FC = () => {
  const [isOpen, setIsOpen] = useState(false)

  const open = () => setIsOpen(true)
  const close = () => setIsOpen(false)

  return (
    <div>
      <ToolbarPrimitive.Root
        className={`${styles.root} ${isOpen ? styles.open : styles.closed}`}
      >
        <ZoomControls setIsOpen={close} />
      </ToolbarPrimitive.Root>
      {!isOpen && (
        <button onClick={open} className={styles.root}>
          <Ellipsis color="#FFF" />
        </button>
      )}
    </div>
  )
}

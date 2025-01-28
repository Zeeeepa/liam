import { Ellipsis } from '@liam-hq/ui'
import * as ToolbarPrimitive from '@radix-ui/react-toolbar'
import { useState } from 'react'
import type { FC } from 'react'
import styles from './Toolbar.module.css'
import { ZoomControls } from './ZoomControls'

export const Toolbar: FC = () => {
  const [isOpen, setIsOpen] = useState(false)

  const toggle = () => setIsOpen((prev) => !prev)

  return (
    <ToolbarPrimitive.Root className={`${styles.root} ${isOpen ? styles.open : styles.closed}`}>
      <div className={isOpen ? styles.hidden : styles.buttonContainer}>
        <button onClick={toggle} className={styles.button}>
          <Ellipsis color="#FFF" />
        </button>
      </div>
      <div className={!isOpen ? styles.hidden : ''}>
        <ZoomControls setIsOpen={toggle} />
      </div>
    </ToolbarPrimitive.Root>
  )
}

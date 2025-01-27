import { useState } from "react";
import * as ToolbarPrimitive from '@radix-ui/react-toolbar'
import type { FC } from 'react'
import styles from './Toolbar.module.css'
import { ZoomControls } from './ZoomControls'
import { Ellipsis } from '@liam-hq/ui'

export const Toolbar: FC = () => {
  const [isOpen, setIsOpen] = useState(false);
  const close = () => setIsOpen(false);

  return (
    isOpen ?
    <ToolbarPrimitive.Root className={styles.root}>
      <ZoomControls setIsOpen={close}/>
    </ToolbarPrimitive.Root>
    :
    <button onClick={() => setIsOpen(true)} className={styles.root}>
      <Ellipsis color="#FFF"/>
    </button>
  )
}

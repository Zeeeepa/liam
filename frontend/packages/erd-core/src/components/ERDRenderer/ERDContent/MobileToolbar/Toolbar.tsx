import * as ToolbarPrimitive from '@radix-ui/react-toolbar'
import type { FC } from 'react'
import { ShowModeMenu } from './ShowModeMenu'
import styles from './Toolbar.module.css'
import { ZoomControls } from './ZoomControls'

export const Toolbar: FC = () => {
  return (
    <ToolbarPrimitive.Root className={styles.root}>
      <ZoomControls />
      <ShowModeMenu />
    </ToolbarPrimitive.Root>
  )
}

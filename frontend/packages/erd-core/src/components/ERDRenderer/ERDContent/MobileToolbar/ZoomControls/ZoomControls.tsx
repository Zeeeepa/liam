import { toolbarActionLogEvent } from '@/features/gtm/utils'
import { useVersion } from '@/providers'
import { useUserEditingStore } from '@/stores'
import { IconButton, Minus, Plus } from '@liam-hq/ui'
import { ToolbarButton } from '@radix-ui/react-toolbar'
import { useReactFlow, useStore } from '@xyflow/react'
import { type FC, useCallback } from 'react'
import { FitviewButton } from './FitviewButton'
import { ShowModeMenu } from './ShowModeMenu'
import { TidyUpButton } from './TidyUpButton'
import styles from './ZoomControls.module.css'

type Props = {
  setIsOpen: () => void
}

export const ZoomControls: FC<Props> = ({ setIsOpen }) => {
  const zoomLevel = useStore((store) => store.transform[2])
  const { zoomIn, zoomOut } = useReactFlow()
  const { showMode } = useUserEditingStore()
  const { version } = useVersion()

  const handleClickZoomOut = useCallback(() => {
    toolbarActionLogEvent({
      element: 'zoom',
      zoomLevel: zoomLevel.toFixed(2),
      showMode,
      platform: version.displayedOn,
      gitHash: version.gitHash,
      ver: version.version,
      appEnv: version.envName,
    })
    zoomOut()
  }, [zoomOut, zoomLevel, showMode, version])

  const handleClickZoomIn = useCallback(() => {
    toolbarActionLogEvent({
      element: 'zoom',
      zoomLevel: zoomLevel.toFixed(2),
      showMode: showMode,
      platform: version.displayedOn,
      gitHash: version.gitHash,
      ver: version.version,
      appEnv: version.envName,
    })
    zoomIn()
  }, [zoomIn, zoomLevel, showMode, version])

  return (
    <div className={styles.wrapper}>
      <div className={styles.zoomLevelText}>
        <div className={styles.zoom}>Zoom</div>
        <div className={styles.zoomPercent}>{Math.floor(zoomLevel * 100)}%</div>
      </div>
      <hr className={styles.divider} />
      <div className={styles.buttonGroup}>
        <ToolbarButton
          asChild
          onClick={handleClickZoomIn}
          className={styles.menuButton}
        >
          <IconButton icon={<Plus />} tooltipContent="Zoom In">
            Zoom in
          </IconButton>
        </ToolbarButton>
        <ToolbarButton
          asChild
          onClick={handleClickZoomOut}
          className={styles.menuButton}
        >
          <IconButton icon={<Minus />} tooltipContent="Zoom Out">
            Zoom out
          </IconButton>
        </ToolbarButton>

        <FitviewButton />
        <TidyUpButton />
      </div>
      <hr className={styles.divider} />

      <ShowModeMenu />
      <button className={styles.button} onClick={setIsOpen}>
        close
      </button>
    </div>
  )
}

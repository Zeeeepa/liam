import {
  type FC,
  type PropsWithChildren,
  createContext,
  useContext,
  useState,
} from 'react'

type ERDContentContextState = {
  loading: boolean
  initializeComplete: boolean
  onceAutoLayoutComplete: boolean
}

type ERDContentContextActions = {
  setLoading: (loading: boolean) => void
  setInitializeComplete: (initializeComplete: boolean) => void
  setOnceAutoLayoutComplete: (onceAutoLayoutComplete: boolean) => void
}

type ERDContentConextValue = {
  state: ERDContentContextState
  actions: ERDContentContextActions
}

const ERDContentContext = createContext<ERDContentConextValue>({
  state: {
    loading: true,
    initializeComplete: false,
    onceAutoLayoutComplete: false,
  },
  actions: {
    setLoading: () => {},
    setInitializeComplete: () => {},
    setOnceAutoLayoutComplete: () => {},
  },
})

export const useERDContentContext = () => useContext(ERDContentContext)

export const ERDContentProvider: FC<PropsWithChildren> = ({ children }) => {
  const [loading, setLoading] = useState(true)
  const [initializeComplete, setInitializeComplete] = useState(false)
  const [onceAutoLayoutComplete, setOnceAutoLayoutComplete] = useState(false)

  return (
    <ERDContentContext.Provider
      value={{
        state: { loading, initializeComplete, onceAutoLayoutComplete },
        actions: { setLoading, setInitializeComplete, setOnceAutoLayoutComplete },
      }}
    >
      {children}
    </ERDContentContext.Provider>
  )
}

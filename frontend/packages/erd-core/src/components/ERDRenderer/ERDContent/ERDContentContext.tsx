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
}

type ERDContentContextActions = {
  setLoading: (loading: boolean) => void
  setInitializeComplete: (initializeComplete: boolean) => void
}

type ERDContentConextValue = {
  state: ERDContentContextState
  actions: ERDContentContextActions
}

const ERDContentContext = createContext<ERDContentConextValue>({
  state: {
    loading: true,
    initializeComplete: false,
  },
  actions: {
    setLoading: () => {},
    setInitializeComplete: () => {},
  },
})

export const useERDContentContext = () => useContext(ERDContentContext)

export const ERDContentProvider: FC<PropsWithChildren> = ({ children }) => {
  const [loading, setLoading] = useState(true)
  const [initializeComplete, setInitializeComplete] = useState(false)

  return (
    <ERDContentContext.Provider
      value={{
        state: { loading, initializeComplete },
        actions: { setLoading, setInitializeComplete },
      }}
    >
      {children}
    </ERDContentContext.Provider>
  )
}

#use node.js, if serverless why not use 14 as that would be just as viable?
FROM node:16

#directory to working
WORKDIR /frontend

#copying package files and instalation files
COPY package*.json ./
RUN npm install

#app source code    
COPY . . 

#setup environment
ENV PORT 3000

#Expose the application
EXPOSE 3000

#start application
CMD ["npm", "ci", "start"]
#node js
FROM node:16

#directory to working
WORKDIR /backend


#copying package files and instalation files
COPY package*.json ./
RUN npm install

#app source code    
COPY . . 

#Env variables
ENV PORT 3000

#Expose the application
EXPOSE 3000

#start application
CMD ["npm", "ci", "start"]